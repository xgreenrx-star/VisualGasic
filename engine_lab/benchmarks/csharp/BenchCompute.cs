using Godot;
using Godot.Collections;
using System;

/// <summary>
/// Godot C# port of demo/test_suites/run_benchmarks.gd compute workloads.
/// Checksums must match GDScript / Visual Gasic for comparable timing.
/// </summary>
// BENCH_TOUCH 1788479295905556421
public partial class BenchCompute : RefCounted
{
	public long BenchArithmetic(int iterations, int inner)
	{
		long s = 0;
		for (int i = 0; i < iterations; i++)
		{
			for (int j = 0; j < inner; j++)
			{
				s += (j * 3) - 7;
			}
		}
		return s;
	}

	public long BenchArraySum(int iterations, int size)
	{
		var arr = new long[size];
		for (int i = 0; i < size; i++)
		{
			arr[i] = i;
		}
		long s = 0;
		for (int k = 0; k < iterations; k++)
		{
			for (int i = 0; i < size; i++)
			{
				s += arr[i];
			}
		}
		return s;
	}

	public long BenchStringConcat(int iterations, int inner)
	{
		string s = "";
		for (int i = 0; i < iterations; i++)
		{
			s = "";
			for (int j = 0; j < inner; j++)
			{
				s += "x";
			}
		}
		return s.Length;
	}

	public long BenchBranch(int iterations, int inner)
	{
		long s = 0;
		for (int i = 0; i < iterations; i++)
		{
			for (int j = 0; j < inner; j++)
			{
				if ((j & 1) == 0)
				{
					s += j;
				}
				else
				{
					s -= j;
				}
			}
		}
		return s;
	}

	private static int CallHelper(int x) => x + 1;

	public long BenchCall(int iterations, int inner)
	{
		int s = 0;
		for (int i = 0; i < iterations; i++)
		{
			for (int j = 0; j < inner; j++)
			{
				s = CallHelper(s);
			}
		}
		return s;
	}

	public long BenchArrayDict(int iterations, int size)
	{
		if (iterations <= 0 || size <= 0)
		{
			return 0;
		}

		var arr = new long[size];
		var keys = new string[size];
		var dict = new Dictionary();
		for (int i = 0; i < size; i++)
		{
			arr[i] = i;
			keys[i] = i.ToString();
			dict[keys[i]] = size - i;
		}

		long sum = 0;
		for (int iter = 0; iter < iterations; iter++)
		{
			for (int i = 0; i < size; i++)
			{
				sum += arr[i];
				sum += (long)dict[keys[i]];
			}
		}
		return sum;
	}

	public long BenchDictFastGet(int iterations, int size)
	{
		if (iterations <= 0 || size <= 0)
		{
			return 0;
		}

		var dict = new Dictionary();
		var keys = new string[size];
		for (int i = 0; i < size; i++)
		{
			string key = i.ToString();
			keys[i] = key;
			dict[key] = i;
		}

		long sum = 0;
		for (int iter = 0; iter < iterations; iter++)
		{
			for (int i = 0; i < size; i++)
			{
				sum += (long)dict[keys[i]];
			}
		}
		return sum;
	}

	public long BenchDictFastSet(int iterations, int size)
	{
		if (iterations <= 0 || size <= 0)
		{
			return 0;
		}

		var dict = new Dictionary();
		var keys = new string[size];
		for (int i = 0; i < size; i++)
		{
			string key = i.ToString();
			keys[i] = key;
			dict[key] = 0;
		}

		long sum = 0;
		for (int iter = 0; iter < iterations; iter++)
		{
			for (int i = 0; i < size; i++)
			{
				long value = iter + i;
				dict[keys[i]] = value;
				sum += value;
			}
		}
		return sum;
	}

	public long BenchInterop(int iterations, int inner)
	{
		if (iterations <= 0 || inner <= 0)
		{
			return 0;
		}

		var node = new Node();
		const string prefix = "bench_";
		long checksum = 0;
		for (int i = 0; i < iterations; i++)
		{
			for (int j = 0; j < inner; j++)
			{
				node.Name = prefix + j;
				checksum += node.Name.ToString().Length;
			}
		}
		node.Free();
		return checksum;
	}

	public long BenchAllocations(int iterations, int size)
	{
		if (iterations <= 0 || size <= 0)
		{
			return 0;
		}

		long sum = 0;
		for (int iter = 0; iter < iterations; iter++)
		{
			var arr = new long[size];
			string text = "";
			for (int i = 0; i < size; i++)
			{
				arr[i] = iter + i;
				text += "x";
				sum += arr[i];
			}
			sum += text.Length;
		}
		return sum;
	}

	public long BenchAllocationsFast(int iterations, int size)
	{
		if (iterations <= 0 || size <= 0)
		{
			return 0;
		}

		long sum = 0;
		for (int iter = 0; iter < iterations; iter++)
		{
			var arr = new long[size];
			for (int i = 0; i < size; i++)
			{
				arr[i] = i;
			}
			sum += size;
		}
		return sum;
	}

	/// <summary>File IO workload; returns elapsed_us + checksum like GD/VG runners.</summary>
	public Godot.Collections.Dictionary BenchFileIO(int iterations, int size)
	{
		if (iterations <= 0 || size <= 0)
		{
			return new Godot.Collections.Dictionary { { "elapsed_us", 0 }, { "checksum", 0 } };
		}

		ulong start = Time.GetTicksUsec();
		string line = "";
		for (int i = 0; i < size; i++)
		{
			line += "x";
		}

		using var writer = FileAccess.Open("user://bench_io_cs.txt", FileAccess.ModeFlags.Write);
		if (writer != null)
		{
			for (int iter = 0; iter < iterations; iter++)
			{
				writer.StoreLine(line);
			}
		}

		string readLine = "";
		using var reader = FileAccess.Open("user://bench_io_cs.txt", FileAccess.ModeFlags.Read);
		if (reader != null)
		{
			readLine = reader.GetLine();
		}

		long elapsed = (long)(Time.GetTicksUsec() - start);
		return new Godot.Collections.Dictionary
		{
			{ "elapsed_us", elapsed },
			{ "checksum", readLine.Length },
		};
	}
}
