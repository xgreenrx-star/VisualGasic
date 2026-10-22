/* Persistent Sherpa-ONNX / Kokoro TTS worker for Visual Gasic.
 *
 * Loads the ~330 MB English model once, then synthesizes jobs from a queue
 * directory. Callers write a *.req file and wait for matching *.ok / *.err.
 *
 * Usage:
 *   vg-tts-daemon <model.onnx> <voices.bin> <tokens.txt> <espeak-ng-data> <queue_dir>
 *
 * Request file (UTF-8, key=value, text= last):
 *   sid=9
 *   speed=0.92
 *   silence=0.38
 *   out=/abs/path.wav
 *   text=Spoken words
 */
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <direct.h>
#include <io.h>
#include <windows.h>
#define PATH_SEP '\\'
#define mkdir_p(path) _mkdir(path)
static void sleep_ms(int ms) { Sleep((DWORD)ms); }
static int pid_of_self(void) { return (int)GetCurrentProcessId(); }
static void lower_priority(void) {
	SetPriorityClass(GetCurrentProcess(), BELOW_NORMAL_PRIORITY_CLASS);
	SetEnvironmentVariableA("OMP_NUM_THREADS", "2");
	SetEnvironmentVariableA("OMP_WAIT_POLICY", "PASSIVE");
	SetEnvironmentVariableA("KMP_BLOCKTIME", "0");
}
#else
#include <dirent.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#define PATH_SEP '/'
#define mkdir_p(path) mkdir(path, 0755)
static void sleep_ms(int ms) {
	struct timespec ts;
	ts.tv_sec = ms / 1000;
	ts.tv_nsec = (long)(ms % 1000) * 1000000L;
	nanosleep(&ts, NULL);
}
static int pid_of_self(void) { return (int)getpid(); }
static void lower_priority(void) {
	nice(10);
	setenv("OMP_NUM_THREADS", "2", 1);
	setenv("OMP_WAIT_POLICY", "PASSIVE", 1);
	setenv("KMP_BLOCKTIME", "0", 1);
}
#endif

#include "sherpa-onnx/c-api/c-api.h"

#define MAX_PATH_LEN 4096
#define MAX_TEXT_LEN 8192
#define IDLE_EXIT_MS (10 * 60 * 1000)

static volatile int g_run = 1;
static const SherpaOnnxOfflineTts *g_tts = NULL;

#ifndef _WIN32
static void on_signal(int sig) {
	(void)sig;
	g_run = 0;
}
#endif

static void path_join(char *out, size_t n, const char *a, const char *b) {
	size_t la = strlen(a);
	int slash = la > 0 && (a[la - 1] == '/' || a[la - 1] == '\\');
	if (slash) {
		snprintf(out, n, "%s%s", a, b);
	} else {
		snprintf(out, n, "%s%c%s", a, PATH_SEP, b);
	}
}

static void write_text_file(const char *path, const char *body) {
	FILE *fp = fopen(path, "wb");
	if (!fp) {
		return;
	}
	fputs(body, fp);
	fclose(fp);
}

static int write_pid(const char *path) {
	char buf[64];
	snprintf(buf, sizeof(buf), "%d\n", pid_of_self());
	FILE *fp = fopen(path, "wb");
	if (!fp) {
		return 0;
	}
	fputs(buf, fp);
	fclose(fp);
	return 1;
}

static void trim(char *s) {
	size_t n;
	char *p = s;
	while (*p && isspace((unsigned char)*p)) {
		p++;
	}
	if (p != s) {
		memmove(s, p, strlen(p) + 1);
	}
	n = strlen(s);
	while (n > 0 && isspace((unsigned char)s[n - 1])) {
		s[--n] = 0;
	}
}

typedef struct Job {
	int sid;
	float speed;
	float silence;
	char out[MAX_PATH_LEN];
	char text[MAX_TEXT_LEN];
	char stem[MAX_PATH_LEN];
} Job;

static int parse_job(const char *path, Job *job) {
	char line[MAX_TEXT_LEN];
	FILE *fp = fopen(path, "rb");
	if (!fp) {
		return 0;
	}
	memset(job, 0, sizeof(*job));
	job->sid = 9;
	job->speed = 1.0f;
	job->silence = 0.2f;
	while (fgets(line, sizeof(line), fp)) {
		char *nl = strchr(line, '\n');
		if (nl) {
			*nl = 0;
		}
		if (line[0] && line[strlen(line) - 1] == '\r') {
			line[strlen(line) - 1] = 0;
		}
		if (strncmp(line, "sid=", 4) == 0) {
			job->sid = atoi(line + 4);
		} else if (strncmp(line, "speed=", 6) == 0) {
			job->speed = (float)atof(line + 6);
		} else if (strncmp(line, "silence=", 8) == 0) {
			job->silence = (float)atof(line + 8);
		} else if (strncmp(line, "out=", 4) == 0) {
			strncpy(job->out, line + 4, sizeof(job->out) - 1);
		} else if (strncmp(line, "text=", 5) == 0) {
			strncpy(job->text, line + 5, sizeof(job->text) - 1);
		}
	}
	fclose(fp);
	trim(job->out);
	trim(job->text);
	if (job->speed < 0.5f) {
		job->speed = 0.5f;
	}
	if (job->speed > 2.0f) {
		job->speed = 2.0f;
	}
	if (job->silence < 0.02f) {
		job->silence = 0.02f;
	}
	if (job->silence > 1.0f) {
		job->silence = 1.0f;
	}
	return job->out[0] && job->text[0];
}

static void stem_from_req(const char *req, char *stem, size_t n) {
	size_t len = strlen(req);
	if (len > 4 && strcmp(req + len - 4, ".req") == 0) {
		if (len - 4 >= n) {
			len = n + 3;
		}
		memcpy(stem, req, len - 4);
		stem[len - 4] = 0;
	} else {
		strncpy(stem, req, n - 1);
		stem[n - 1] = 0;
	}
}

#ifdef _WIN32
static int next_request(const char *queue, char *req_path, size_t n) {
	char pattern[MAX_PATH_LEN];
	WIN32_FIND_DATAA find;
	HANDLE h;
	int found = 0;
	char best[MAX_PATH_LEN];
	best[0] = 0;
	path_join(pattern, sizeof(pattern), queue, "*.req");
	h = FindFirstFileA(pattern, &find);
	if (h == INVALID_HANDLE_VALUE) {
		return 0;
	}
	do {
		if (find.cFileName[0] == '.') {
			continue;
		}
		if (!found || strcmp(find.cFileName, best) < 0) {
			strncpy(best, find.cFileName, sizeof(best) - 1);
			found = 1;
		}
	} while (FindNextFileA(h, &find));
	FindClose(h);
	if (!found) {
		return 0;
	}
	path_join(req_path, n, queue, best);
	return 1;
}
#else
static int next_request(const char *queue, char *req_path, size_t n) {
	DIR *dir = opendir(queue);
	struct dirent *ent;
	int found = 0;
	char best[MAX_PATH_LEN];
	best[0] = 0;
	if (!dir) {
		return 0;
	}
	while ((ent = readdir(dir)) != NULL) {
		size_t len = strlen(ent->d_name);
		if (len < 5 || strcmp(ent->d_name + len - 4, ".req") != 0) {
			continue;
		}
		if (!found || strcmp(ent->d_name, best) < 0) {
			strncpy(best, ent->d_name, sizeof(best) - 1);
			found = 1;
		}
	}
	closedir(dir);
	if (!found) {
		return 0;
	}
	path_join(req_path, n, queue, best);
	return 1;
}
#endif

static int synthesize(const Job *job) {
	const SherpaOnnxGeneratedAudio *audio;
	int ok;
	if (!g_tts) {
		return 0;
	}
	audio = SherpaOnnxOfflineTtsGenerate(g_tts, job->text, job->sid, job->speed);
	if (!audio || !audio->samples || audio->n <= 0) {
		if (audio) {
			SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);
		}
		return 0;
	}
	ok = SherpaOnnxWriteWave(audio->samples, audio->n, audio->sample_rate, job->out);
	SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);
	return ok != 0;
}

static void finish_job(const Job *job, int ok) {
	char path[MAX_PATH_LEN];
	snprintf(path, sizeof(path), "%s.req", job->stem);
	remove(path);
	if (ok) {
		snprintf(path, sizeof(path), "%s.ok", job->stem);
		write_text_file(path, "ok\n");
	} else {
		snprintf(path, sizeof(path), "%s.err", job->stem);
		write_text_file(path, "tts failed\n");
	}
}

static void warmup(void) {
	Job job;
	memset(&job, 0, sizeof(job));
	job.sid = 9;
	job.speed = 0.92f;
	job.silence = 0.2f;
	snprintf(job.out, sizeof(job.out), "%s", "/tmp/vg-tts-warmup.wav");
#ifdef _WIN32
	{
		char tmp[MAX_PATH_LEN];
		DWORD n = GetTempPathA((DWORD)sizeof(tmp), tmp);
		if (n > 0 && n < sizeof(tmp)) {
			snprintf(job.out, sizeof(job.out), "%svg-tts-warmup.wav", tmp);
		}
	}
#endif
	strncpy(job.text, "Ready.", sizeof(job.text) - 1);
	if (synthesize(&job)) {
		remove(job.out);
	}
}

int main(int argc, char **argv) {
	SherpaOnnxOfflineTtsConfig config;
	char ready_path[MAX_PATH_LEN];
	char pid_path[MAX_PATH_LEN];
	char lock_path[MAX_PATH_LEN];
	char req_path[MAX_PATH_LEN];
	int idle_ms = 0;
#ifndef _WIN32
	int lock_fd;
#endif

	if (argc != 6) {
		fprintf(stderr, "usage: vg-tts-daemon model voices tokens data_dir queue_dir\n");
		return 2;
	}

	mkdir_p(argv[5]);
	path_join(ready_path, sizeof(ready_path), argv[5], "ready");
	path_join(pid_path, sizeof(pid_path), argv[5], "pid");
	path_join(lock_path, sizeof(lock_path), argv[5], "lock");

#ifndef _WIN32
	lock_fd = open(lock_path, O_CREAT | O_RDWR, 0644);
	if (lock_fd < 0) {
		fprintf(stderr, "vg-tts-daemon: cannot open lock %s\n", lock_path);
		return 1;
	}
	if (flock(lock_fd, LOCK_EX | LOCK_NB) != 0) {
		return 0;
	}
	signal(SIGTERM, on_signal);
	signal(SIGINT, on_signal);
#endif
	lower_priority();

	memset(&config, 0, sizeof(config));
	config.model.kokoro.model = argv[1];
	config.model.kokoro.voices = argv[2];
	config.model.kokoro.tokens = argv[3];
	config.model.kokoro.data_dir = argv[4];
	config.model.kokoro.length_scale = 1.0f;
	config.model.num_threads = 2;
	config.model.debug = 0;
	config.model.provider = "cpu";
	config.max_num_sentences = 1;
	config.silence_scale = 0.2f;

	g_tts = SherpaOnnxCreateOfflineTts(&config);
	if (!g_tts) {
		fprintf(stderr, "vg-tts-daemon: failed to load Kokoro model\n");
		return 1;
	}

	warmup();
	write_pid(pid_path);
	write_text_file(ready_path, "ready\n");
	fprintf(stdout, "READY\n");
	fflush(stdout);

	while (g_run) {
		if (next_request(argv[5], req_path, sizeof(req_path))) {
			Job job;
			idle_ms = 0;
			if (!parse_job(req_path, &job)) {
				stem_from_req(req_path, job.stem, sizeof(job.stem));
				finish_job(&job, 0);
				continue;
			}
			stem_from_req(req_path, job.stem, sizeof(job.stem));
			finish_job(&job, synthesize(&job));
			continue;
		}
		sleep_ms(20);
		idle_ms += 20;
		if (idle_ms >= IDLE_EXIT_MS) {
			break;
		}
	}

	remove(ready_path);
	remove(pid_path);
	if (g_tts) {
		SherpaOnnxDestroyOfflineTts(g_tts);
		g_tts = NULL;
	}
	return 0;
}
