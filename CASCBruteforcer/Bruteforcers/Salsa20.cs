﻿using CASCBruteforcer.Helpers;
using OpenCLlib;
using System;
using System.Diagnostics;
using System.Linq;
using System.Text;

namespace CASCBruteforcer.Bruteforcers
{
	class Salsa20 : IHash
	{
		private byte[] EncryptedMagic;
		private byte[] DecryptedMagic;
		private uint[] IV;
		private ulong LowerOffset;
		private ulong UpperOffset;
		private byte IncrementMode; // &1: X, &2: Y		

		public void LoadParameters(params string[] args)
		{
			if (args.Length != 7)
				throw new ArgumentException("Invalid argument amount");

			EncryptedMagic = args[1].ToByteArray();
			if (EncryptedMagic.Length != 8)
				throw new ArgumentException("Invalid Encrypted Magic size");

			DecryptedMagic = args[2].ToByteArray();
			if (DecryptedMagic.Length != 8)
				throw new ArgumentException("Invalid Decrypted Magic size");

			IV = ToUIntArray(args[3]);

			if (!ulong.TryParse(args[4], out LowerOffset))
				throw new ArgumentException("Invalid Lower offset");

			Console.WriteLine($"Lower offset: {LowerOffset}");

			if (!ulong.TryParse(args[5], out UpperOffset))
				throw new ArgumentException("Invalid Upper offset");

			Console.WriteLine($"Upper offset: {UpperOffset}");

			if (!byte.TryParse(args[6], out IncrementMode) || IncrementMode > 3)
				throw new ArgumentException("Invalid Increment Flag");
		}

		public void Start()
		{
			KernelWriter kernel = new KernelWriter(Properties.Resources.Salsa);
			kernel.ReplaceArray("DATA", EncryptedMagic);
			kernel.ReplaceArray("MAGIC", DecryptedMagic);
			kernel.Replace("IV0", IV[0]);
			kernel.Replace("IV1", IV[1]);

			// load CL
			Console.WriteLine("Loading kernel. This may take a while...");
			MultiCL cl = new MultiCL();
			cl.SetKernel(kernel.ToString(), "Bruteforce");

			// limit each workload to uint.MaxValue but iterate for ulong.MaxValue
			long parts = (long)(ulong.MaxValue / uint.MaxValue);
			ulong completed = 0;

			Stopwatch time = Stopwatch.StartNew();
			Stopwatch ptime = Stopwatch.StartNew();
			Console.WriteLine($"Starting Salsa Hashing :: {ulong.MaxValue} combinations over {parts} part(s) ");

			for (long i = 0; i < parts; i++)
			{
				// workload size for this iteration
				uint size = (ulong.MaxValue - completed <= uint.MaxValue ? (uint)(ulong.MaxValue - completed) : uint.MaxValue);

				// lower key start value, upper key start value, increment type, offset
				cl.SetParameter(LowerOffset, UpperOffset, IncrementMode, completed);
				cl.Invoke(0, size, cl.Context.Length); // use all contexts

				if (i % 50 == 0)
				{
					Console.WriteLine($"Part {i}/{parts}, {completed += size} completed in {ptime.Elapsed.TotalSeconds:0.00} secs ({time.Elapsed.TotalSeconds:0.00} secs total)");
					PrintStats(completed, size, time);
					ptime = Stopwatch.StartNew();
				}
			}

			time.Stop();
			Console.WriteLine($"Completed in {time.Elapsed.TotalSeconds:0.00} secs");
		}

		private void PrintStats(ulong completed, uint size, Stopwatch time)
		{
			unchecked
			{
				ulong x = LowerOffset;
				ulong y = UpperOffset;
				if ((IncrementMode & 1) == 1)
					x += completed;
				if ((IncrementMode & 2) == 2)
					y += completed;

				if (time.Elapsed.TotalSeconds > 0)
					Console.WriteLine($"Current offsets Lower: {x}  Upper: {y} Speed: {completed / (ulong)(time.Elapsed.TotalSeconds)} h/sec");
				else
					Console.WriteLine($"Current offsets Lower: {x}  Upper: {y} Speed: {0} h/sec");
			}
		}

		private uint[] ToUIntArray(string str)
		{
			str = str.Replace(" ", string.Empty);

			// hex to byte array
			byte[] data = Enumerable.Range(0, str.Length / 2).Select(x => Convert.ToByte(str.Substring(x * 2, 2), 16)).Take(8).ToArray();

			// copy to buffer
			uint[] result = new uint[2];
			Buffer.BlockCopy(data, 0, result, 0, data.Length);
			return result;
		}
	}

	public static class CStringExtensions
	{
		public static byte[] ToByteArray(this string str)
		{
			str = str.Replace(" ", string.Empty);

			var res = new byte[str.Length / 2];
			for (int i = 0; i < res.Length; ++i)
			{
				res[i] = Convert.ToByte(str.Substring(i * 2, 2), 16);
			}
			return res;
		}
	}
}
