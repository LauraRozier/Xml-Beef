using System;
using System.IO;
using Xml_Beef;

namespace Xml_Beef_Test
{
	class Program
	{
		const String CTestFile = "text.xml";

		static int Main()
		{
			String testStr = scope:: .();
			FileStream fs = new .();
			fs.Open(CTestFile, .Read, .None);

			StreamReader sr = new .(fs, .UTF8, false, 4096);
			sr.ReadToEnd(testStr);
			delete sr;
			fs.Close();
			delete fs;

			Console.WriteLine("File's text :{}{}{}", Environment.NewLine, testStr, Environment.NewLine);

			Xml test = scope:: .();
			test.LoadFromFile(CTestFile);
			//test.Test();
			
			String tmp = scope:: .();
			test.SaveToString(tmp);
			//test.SaveToFile(CTestFile);

			Console.WriteLine("Parsed result text :{}{}{}", Environment.NewLine, tmp, Environment.NewLine);
			Console.WriteLine(testStr.Equals(tmp, .OrdinalIgnoreCase) ? "Strings are identical" : "Strings differ somehow");

			Console.WriteLine("{}Press [Enter] to exit the program...", Environment.NewLine);
			Console.Read();

			return 0;
		}
	}
}
