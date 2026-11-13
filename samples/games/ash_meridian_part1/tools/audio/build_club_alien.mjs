import {fileURLToPath} from "node:url";
import {resolve} from "node:path";
import {spawnSync} from "node:child_process";

const root = fileURLToPath(new URL("../../", import.meta.url));
const godot = process.env.GODOT_BIN ?? resolve(root, "../../../Godot_v4.6.1-stable_linux.x86_64");
const result = spawnSync(godot, ["--headless", "--audio-driver", "Dummy", "--path", root,
	"--script", "tools/audio/bake_club_alien.gd"], {
	env: {...process.env, ASH_SPEECH_LIVE: "1"},
	stdio: "inherit"
});
if (result.error) throw result.error;
process.exit(result.status ?? 1);
