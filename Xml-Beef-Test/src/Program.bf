using System;
using Xml_Beef;

namespace Xml_Beef_Test
{
	class Program
	{
		static int Main()
		{
			String tmp = scope:: .();
			Xml test = scope:: .();
			test.Test();

			test.AsString(tmp);
			Console.WriteLine(tmp);

			Console.WriteLine("{}Press [Enter] to exit the program...", Environment.NewLine);
			Console.Read();

			return 0;
		}
	}
}
