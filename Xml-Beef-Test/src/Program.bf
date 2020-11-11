using System;
using System.IO;
using Xml_Beef;

namespace Xml_Beef_Test
{
	class Program
	{
		const String CTestFile = "text.xml";
		const String CTestFile2 = "writeTest.xml";

		static int Main()
		{
			TestFile();
			TestProcedural();

			Console.WriteLine("Press [Enter] to exit the program...");
			Console.Read();

			return 0;
		}

		static void TestFile()
		{
			// Read file data into a stream
			String testStr = scope:: .();
			FileStream fs = new .();
			fs.Open(CTestFile, .Read, .None);

			StreamReader sr = new .(fs, .UTF8, false, 4096);
			sr.ReadToEnd(testStr);
			delete sr;

			fs.Close();
			delete fs;

			// Echo file's data
			Console.WriteLine("File's text :{}{}{}", Environment.NewLine, testStr, Environment.NewLine);

			// Create XML document object and fill it with data
			Xml test = scope:: .();
			test.LoadFromFile(CTestFile);

			// Save the data to a string
			String tmp = scope:: .();
			test.SaveToString(tmp);

			// Echo the parsed result and equality check
			Console.WriteLine("Parsed result text :{}{}{}", Environment.NewLine, tmp, Environment.NewLine);
			Console.WriteLine(
				testStr.Equals(tmp, .OrdinalIgnoreCase) ? "Strings are identical{}{}" : "Strings differ somehow{}{}",
				Environment.NewLine,
				Environment.NewLine
			);
		}

		static void TestProcedural()
		{
			// Create XML document object and fill it with data
			Xml test = scope:: .();

			test.ChildNodes.Add(.DocType)
				.SetText("html");

			XmlNode html = test.AddChild("html")
				.SetAttribute("lang", "en-us")
				.SetAttribute("dir", "ltr");

			XmlNode head = html.AddChild("head");

			head.AddChild("title")
				.SetText("This is a title");

			XmlNode body = html.AddChild("body");
			body.AddChild("SomeChild")
				.SetAttribute("test", "val")
				.SetAttribute("serious", "testval");

			body.AddChild("AnotherChild")
				.SetAttribute("test", "321")
				.AddChild("ChildChild")
					.SetAttribute("Works", "Holy hecc");

			body.AddChild("YetAnotherChild")
				.SetAttribute("test", "123");

			body.Find("AnotherChild")
				.Find("ChildChild")
					.AddChild("ChildChildChild")
						.SetAttribute("SomeFlag")
						.SetAttribute("SomeValue", "val");

			// Write the data to a file
			test.SaveToFile(CTestFile2);

			// Write the data to a string and echo it
			String tmp = scope:: .();
			test.SaveToString(tmp);
			Console.WriteLine("Procedurally generated XML value :{}{}{}", Environment.NewLine, tmp, Environment.NewLine);
		}
	}
}
