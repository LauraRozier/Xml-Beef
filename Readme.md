# Xml-Beef
A single-file XML parser written in BeefLang.

#### Notes
Please keep in mind you only have to manage the lifetime of the Xml object.  
Every child item's lifetime is managed by the library itself.

## Examples

### Parsing XML files into objects
The library efficiently reads streams to parse their content. There are utility methods for strings and files.

```csharp
using System;
using Xml_Beef;

namespace Sample
{
    class Program
    {
        static int Main()
        {
            Xml xml = new Xml();

            // This will create a filestream that reads the file 4096 (default) bytes at a time
            xml.LoadFromFile("path/to/file.html");

            // Perform your edits as needed
            XmlNode node = xml.Find("div", "id", "some_id_123");
            XmlNode child = node.AddChild("a");
            child.Text = "Xml-Beef";
            child.SetAttribute("href", "https://github.com/thibmo/Xml-Beef");
            child.SetAttribute("target", "_blank");

            // Save the data to a string
            String tmp = new String();
            xml.SaveToString(tmp);

            // Delete the XML object, we no longer need it
            delete xml;

            Console.WriteLine("Procedurally generated XML value :{}{}{}", Environment.NewLine, tmp, Environment.NewLine);

            // Cleanup the remaining objects
            delete tmp;

            Console.WriteLine("Press [Enter] to exit the program...");
            Console.Read();

            return 0;
        }
    }
}
```

### Procedurally generating an XML file
The library can also write the XML content to streams, strings and files.

```csharp
using System;
using Xml_Beef;

namespace Sample
{
    class Program
    {
        static int Main()
        {
            String tmp = scope:: .();
            Xml xml = scope:: .();

            // Create your node and attributes as needed
            XmlNode root = xml.AddChild("root");

            // Note we can chain calls for most modifying method calls
            root.AddChild("child1")
                .SetAttribute("some", "attr")
                .AddChild("child1.1")
                    .AddChild("child1.1.1")
                        .AddChild("child1.1.1.1")
                            .SetAttribute("super", "safe :)");
            XmlNode child2 = root.AddChild("child2");
            child2.AddChild("child2.1")
                .AddChild("child2.1.1")
                .Text = "Some filler Text";
            child2.AddChild("child2.2")
                .AddChild("child2.2.1")
                    .AddChild("child2.2.1.1")
                        .SetText("Use this for the ability to chain calls")
                        .SetAttribute("flags")
                        .SetAttribute("also")
                        .SetAttribute("work");
            child2.AddChild("child2.3")
                .AddChild("child2.3.1");

            // Save the data to a file
            xml.SaveToFile("path/to/file.xml");

            // Save the data to a string
            xml.SaveToString(tmp);
            Console.WriteLine("Procedurally generated XML value :{}{}{}", Environment.NewLine, tmp, Environment.NewLine);

            Console.WriteLine("Press [Enter] to exit the program...");
            Console.Read();

            // Just let objects fall out of scope :)
            return 0;
        }
    }
}
```
