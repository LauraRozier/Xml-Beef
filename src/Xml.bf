using System;
using System.Collections;

/*
** This lib was heavilly inspired by VerySimpleXml
** https://github.com/Dennis1000/verysimplexml/blob/master/Source/Xml.VerySimple.pas
** Credits for the original sources go to the original developer.
**
** I (Thibmo) only ported this lib to pure BeefLang 
*/

namespace Xml_Beef
{
	static
	{
		// 0x20 (' '), 0x0A ('\n'), 0x0D ('\r') and 0x09 ('\t') ordered by most commonly used, to speed searches up
		private const char8[4] CXmlSpaces = .('\x20', '\x0A', '\x0D', '\x09');
	}

	enum XmlNodeType
	{
		None = 0x0000,
		Element = 0x0001,
		Attribute = 0x0002,
		Text = 0x0004,
		CDataSection = 0x0008,
		EntityReference = 0x0010,
		Entity = 0x0020,
		ProcessingInstruction = 0x0040,
		Comment = 0x0080,
		Document = 0x0100,
		DocType = 0x0200,
		DocumentFragment = 0x0400,
		Notation = 0x0800,
		XmlDecl = 0x1000
	}

	public enum XmlAttrType
	{
		Value,
		Flag
	}

	public enum XmlOptions
	{
		None = 0x0000,
		NodeAutoIndent = 0x0001,
		Compact = 0x0002,
		ParseProcessingInstruction = 0x0004,
		PreserveWhiteSpace = 0x0008,
		CaseInsensitive = 0x0010,
		WriteBOM = 0x0020
	}

	enum XmlExtractTextOptions
	{
		None = 0x0000,
		DeleteStopChar = 0x0001,
		StopString = 0x0002
	}

	public class XmlAttribute
	{
		public XmlAttrType AttrType = .Flag;

		public String _name = new .() ~ delete _;
		public String Name
		{
			get { return _name; }
			set { _name.Set(value); }
		}

		protected String _value = new .() ~ delete _;
		public String Value
		{
			get { return _value; }
			set { _value.Set(value); AttrType = .Value; }
		}

		public this() { }

		public this(XmlAttribute val)
		{
			Name.Set(val.Name);
			AttrType = val.AttrType;
			_value.Set(val.Value);
		}

		public this(StringView name, String val)
		{
			Name.Set(name);

			if (!String.IsNullOrWhiteSpace(val))
				Value = val;
		}

		public void AsString(String OutStr)
		{
			if (AttrType == .Flag) {
				OutStr.Set(Name);
			} else {
				OutStr.Clear();
				OutStr.AppendF("{}=\"{}\"", Name, _value);
			}
		}

		// Escape XML reserved characters in the 'val' `System`.`String` 
		public static void EscapeStr(String val)
		{
			val.Replace("&", "&amp;");
			val.Replace("\"", "&quot;");
			val.Replace("<", "&lt;");
			val.Replace(">", "&gt;");
		}

		[Inline]
		public static void EscapeStr(StringView inStr, String outStr)
		{
			outStr.Set(inStr);
			EscapeStr(outStr);
		}
	}

	public class XmlAttributeList : List<XmlAttribute>
	{
		// The xml document that this attribute list belongs to
		protected Xml _document;
		public Xml Document
		{
			get { return _document; }
			set { _document = value; }
		}

		// Adds a value with a name and a value
		public XmlAttribute Add(StringView name, String val = null)
		{
			XmlAttribute result = new .(name, val);
			Add(result);
			return result;
		}

		// Retrieve the attribute with the given name (case insensitive), returns `null` when not found
		public XmlAttribute Find(String name)
		{
			for (int i = 0; i < Count; i++)
				if (mItems[i].Name.Equals(name, StringComparison.OrdinalIgnoreCase))
					return mItems[i];

			XmlAttribute tmp = null;
			return tmp;
		}

		// Indicates if the list contains an attribute with the given name (case insensitive)
		public bool HasAttribute(String name) => Find(name) != null;

		// Deletes an attribute given by name (case insensitive)
		public void Remove(String name)
		{
			XmlAttribute attr = Find(name);

			if (attr != null)
				Remove(attr);
		}

		// Returns the attributes in string representation
		public void AsString(String outStr)
		{
			outStr.Clear();
			String tmp = scope:: .();

			for (let item in this) {
				item.AsString(tmp);
				outStr.AppendF(" {}", tmp);
			}
		}

		// Clears the current list and adds the items from the 'src' `Xml_Beef`.`XmlAttributeList`
		public void Assign(XmlAttributeList src)
		{
			for (var item in this)
				delete item;

			Clear();

			for (let item in src)
				Add(new XmlAttribute(item.Name, item.Value));
		}
	}

	public class XmlNode
	{
		// The xml document that this node belongs to
		protected Xml _document;
		public Xml Document
		{
			get { return _document; }
			set { _document = AttributeList.Document = ChildNodes.Document = value; }
		}

		// All the attributes of this node
		public readonly XmlAttributeList AttributeList;
		
		// List of child nodes, never null
		public readonly XmlNodeList ChildNodes;

		// The node type, see TXmlNodeType
		public XmlNodeType NodeType;

		// Parent node, may be null
		public XmlNode _parent;
		public XmlNode Parent
		{
			get { return _parent; }
			set { _parent = value; }
		}

		// Name of the node
		public String _name = new .() ~ delete _;
		public String Name
		{
			get { return _name; }
			set { _name.Set(value); }
		}

		// Text value of the node
		public String _text = new .() ~ delete _;
		public String Text
		{
			get { return _text; }
			set { _text.Set(value); }
		}

		// Creates a new XML node
		public this(XmlNodeType type = .Element)
		{
			NodeType = type;
			AttributeList = new .();
			ChildNodes = new .();
			ChildNodes.Parent = this;
		}

		// Removes the node from its parent and frees all of it's child nodes
		public ~this()
		{
			Clear();
			delete ChildNodes;
			delete AttributeList;
		}

		// Clears the attributes, the text and all of its child nodes (but not the name)
		public void Clear()
		{
			_text.Clear();
			DeleteAndClearItems!(AttributeList);
			DeleteAndClearItems!(ChildNodes);
		}

		// Find a child node by its name
		public XmlNode Find(String name, XmlNodeType types = .Element) => ChildNodes.Find(name, types);

		// Find a child node by name and attribute name
		public XmlNode Find(String name, String attrName, XmlNodeType types = .Element) => ChildNodes.Find(name, attrName, types);

		// Find a child node by name, attribute name and attribute value
		public XmlNode Find(String name, String attrName, String attrValue, XmlNodeType types = .Element) =>
			ChildNodes.Find(name, attrName, attrValue, types);

		// Return a list of child nodes with the given name and (optional) node types
		public XmlNodeList FindNodes(String name, XmlNodeType types = .Element) => ChildNodes.FindNodes(name, types);

		// Returns True if the attribute exists
		public bool HasAttribute(String name) => AttributeList.HasAttribute(name);

		// Returns True if a child node with that name exits
		public bool HasChild(String name, XmlNodeType types = .Element) => ChildNodes.HasNode(name, types);

		// Add a child node with an optional NodeType (default: ntElement)
		public XmlNode AddChild(String name, XmlNodeType type = .Element) => ChildNodes.Add(name, type);

		// Insert a child node at a specific position with a (optional) NodeType (default: ntElement)
		public XmlNode InsertChild(String name, int pos, XmlNodeType type = .Element)
		{
			XmlNode tmp = ChildNodes.Insert(name, pos, type);

			if (tmp != null)
				tmp.Parent = this;

			return tmp;
		}

		// Setting the node name
		public XmlNode SetName(String value)
		{
			_name.Set(value);
			return this;
		}

		// Setting a node attribute by attribute name and attribute value
		public XmlNode SetAttribute(String name)
		{
			XmlAttribute attr = AttributeList.Find(name);

			if (attr == null)
				attr = AttributeList.Add(name);

			attr.AttrType = .Flag;
			attr.Name = name;
			return this;
		}

		// Setting a node attribute flag by attribute name
		public XmlNode SetAttribute(String name, String value)
		{
			XmlAttribute attr = AttributeList.Find(name);

			if (attr == null)
				attr = AttributeList.Add(name);

			attr.AttrType = .Value;
			attr.Name = name;
			attr.Value = value;
			return this;
		}

		// Setting the node text
		public XmlNode SetText(String value)
		{
			_text.Set(value);
			return this;
		}

		// Returns first child or NIL if there aren't any child nodes
		public XmlNode FirstChild
		{
			get
			{
				if (ChildNodes.Count > 0)
					return ChildNodes.Front;

				XmlNode tmp = null;
				return tmp;
			}
		}

		// Returns last child node or NIL if there aren't any child nodes
		public XmlNode LastChild
		{
			get
			{
				if (ChildNodes.Count > 0)
					return ChildNodes.Back;

				XmlNode tmp = null;
				return tmp;
			}
		}

		// Returns next sibling
		public XmlNode NextSibling
		{
			get
			{
				if (_parent != null)
					return _parent.ChildNodes.NextSibling(this);

				XmlNode tmp = null;
				return tmp;
			}
		}
		// Returns previous sibling
		public XmlNode PreviousSibling
		{
			get
			{
				if (_parent != null)
					return _parent.ChildNodes.PreviousSibling(this);

				XmlNode tmp = null;
				return tmp;
			}
		}

		// Returns True if the node has at least one child node
		public bool HasChildNodes => ChildNodes.Count > 0;

		// Returns True if the node has a text content and no child nodes
		public bool IsTextElement => (!String.IsNullOrWhiteSpace(_text)) && (!HasChildNodes);

		// Attributes of a node, accessible by attribute name (case insensitive)
		public String this[String name]
		{
			get
			{
				XmlAttribute attr = AttributeList.Find(name);
				return attr == null ? "" : attr.Value;
			}
			set { SetAttribute(name, value); }
		}

		// The node name, same as property Name
		public String NodeName
		{
			get { return _name; }
			set { _name.Set(value); }
		}

		// The node text, same as property Text
		public String NodeValue
		{
			get { return _text; }
			set { _text.Set(value); }
		}
	}

	public class XmlNodeList : List<XmlNode>
	{
		// The xml document that this nodeList belongs to
		protected Xml _document;
		public Xml Document
		{
			get { return _document; }
			set { _document = value; }
		}

		protected XmlNode _parent;
		public XmlNode Parent
		{
			get { return _parent; }
			set { _parent = value; }
		}

		
		// Adds a node and sets the parent of the node to the parent of the list
		public new int Add(XmlNode value)
		{
			value.Parent = _parent;
			base.Add(value);
			return Count - 1;
		}

		// Creates a new node of type NodeType (default ntElement) and adds it to the list
		public XmlNode Add(XmlNodeType type = .Element)
		{
			XmlNode tmp = new .(type);
			tmp.Document = _document;
			Add(tmp);
			return tmp;
		}

		// Add a child node with an optional NodeType (default: ntElement)
		public XmlNode Add(String name, XmlNodeType type = .Element)
		{
			XmlNode tmp = Add(type);
			tmp.Name = name;
			return tmp;
		}

		// Find a node by its name (case sensitive), returns NIL if no node is found
		public XmlNode Find(String name, XmlNodeType types = .Element)
		{
			for (XmlNode node in this) {
				if ((types == .None || types.HasFlag(node.NodeType)) && name.Equals(node.Name, .OrdinalIgnoreCase))
					return node;
			}

			XmlNode tmp = null;
			return tmp;
		}

		// Same as Find(), returns a node by its name (case sensitive)
		public XmlNode FindNode(String name, XmlNodeType types = .Element) => Find(name, types);

		// Find a node that has the the given attribute, returns NIL if no node is found
		public XmlNode Find(String name, String attrName, XmlNodeType types = .Element)
		{
			for (XmlNode node in this) {
				if ((types == .None || types.HasFlag(node.NodeType)) && name.Equals(node.Name, .OrdinalIgnoreCase) &&
					node.HasAttribute(attrName))
					return node;
			}

			XmlNode tmp = null;
			return tmp;
		}

		// Find a node that as the given attribute name and value, returns NIL otherwise
		public XmlNode Find(String name, String attrName, String attrValue, XmlNodeType types = .Element)
		{
			for (XmlNode node in this) {
				if ((types == .None || types.HasFlag(node.NodeType)) && name.Equals(node.Name, .OrdinalIgnoreCase) &&
					node.HasAttribute(attrName) && attrValue.Equals(node[attrName], .OrdinalIgnoreCase))
					return node;
			}

			XmlNode tmp = null;
			return tmp;
		}

		// Return a list of child nodes with the given name and (optional) node types
		public XmlNodeList FindNodes(String name, XmlNodeType types = .Element)
		{
			XmlNodeList tmp = new .();
			tmp.Document = _document;

			for (XmlNode node in this) {
				if ((types == .None || types.HasFlag(node.NodeType)) && name.Equals(node.Name, .OrdinalIgnoreCase)) {
					tmp.Parent = node.Parent;
					tmp.Add(node);
				}
			}

			tmp.Parent = null;
			return tmp;
		}

		// Returns True if the list contains a node with the given name
		public bool HasNode(String name, XmlNodeType types = .Element) => Find(name, types) != null;

		// Inserts a node at the given position
		public XmlNode Insert(String name, int pos, XmlNodeType type = .Element)
		{
			XmlNode tmp = new .();
			tmp.Document = _document;
			tmp.Name = name;
			tmp.NodeType = type;
			Insert(pos, tmp);
			return tmp;
		}

		// Returns the first child node, same as .First
		public XmlNode FirstChild => Front;

		// Returns next sibling node
		public XmlNode NextSibling(XmlNode node)
		{
			if (node == null && Count > 0)
				return Front;

			int idx = IndexOf(node);

			if (idx >= 0 && Count > idx + 1)
				return this[idx + 1];
			
			XmlNode tmp = null;
			return tmp;
		}

		// Returns previous sibling node
		public XmlNode PreviousSibling(XmlNode node)
		{
			int idx = IndexOf(node);

			if (idx - 1 >= 0)
				return this[idx - 1];

			XmlNode tmp = null;
			return tmp;
		}

		// Returns the node at the given position
		public XmlNode Get(int idx) => this[idx];
	}

	public class Xml
	{
		protected XmlNode _root;
		protected XmlNode _header;
		protected XmlNode _documentElement;
		protected bool _skipIndent;

		public String LineBreak = new .(Environment.NewLine) ~ delete _;
		public XmlOptions Options = .NodeAutoIndent | .WriteBOM;

		public this()
		{
			_root = new .();
			_root.NodeType = .Document;
			_root.Parent = _root;
			_root.Document = this;
			CreateHeaderNode();
		}

		public ~this()
		{
			delete _root;
			delete _header;
			delete _documentElement;
		}

		public void CreateHeaderNode()
		{
			if (_header != null)
				return;

			_header = new .();
			_header.SetAttribute("version", "1.0");
			_header.SetAttribute("encoding", "utf-8");
		}

		public void FromText()
		{

		}

		public void AsString(String outStr)
		{
			// _header.AttributeList.AsString(outStr);

			for (XmlNode child in _root.ChildNodes) {
				Walk(outStr, "", child);
			}
		}

		private void Walk(String outStr, StringView prefix, XmlNode node)
		{
			if ((node == _root.ChildNodes.Front) || (_skipIndent)) {
				outStr.Append('<');
				_skipIndent = false;
			} else {
				outStr.AppendF("{}{}{}", LineBreak, prefix, '<');
			}

			switch (node.NodeType)
			{
				case .Comment:
				{
					outStr.AppendF("!--{}-->", node.Text);
					return;
				}
				case .DocType:
				{
					outStr.AppendF("!DOCTYPE {}>", node.Text);
					return;
				}
				case .CDataSection:
				{
					outStr.AppendF("<![CDATA[{}]]>", node.Text);
					return;
				}
				case .Text:
				{
					outStr.Append(node.Text);
					_skipIndent = true;
					return;
				}
				case .ProcessingInstruction:
				{
					if (node.AttributeList.Count > 0) {
						String tmp = scope:: .();
						node.AttributeList.AsString(tmp);
						outStr.AppendF("?{}{}?>", node.Name, tmp);
					} else {
						outStr.AppendF("?{}?>", node.Text);
					}

					return;
				}
				case .XmlDecl:
				{
					String tmp = scope:: .();
					node.AttributeList.AsString(tmp);
					outStr.AppendF("?{}{}?>", node.Name, tmp);
					return;
				}
				default: {}
			}

			String tmp = scope:: .();
			node.AttributeList.AsString(tmp);
			outStr.AppendF("{}{}", node.Name, tmp);

			// Self closing tags
			if (String.IsNullOrWhiteSpace(node.Text) && !node.HasChildNodes) {
				outStr.Append("/>");
				return;
			}

			outStr.Append(">");

			if (!String.IsNullOrWhiteSpace(node.Text)) {
				tmp.Set(node.Text);
				EscapeStr(tmp);
				outStr.Append(tmp);

				if (node.HasChildNodes)
					_skipIndent = true;
			}

			// Set indent for child nodes
			String indent = scope:: .();

			if (!Options.HasFlag(.Compact))
				indent.AppendF("{}  ", prefix);

			// Process child nodes
			for (XmlNode child in node.ChildNodes)
				Walk(outStr, indent, child);

			if (node.HasChildNodes && !_skipIndent) {
				outStr.AppendF("{}{}</{}>", LineBreak, prefix, node.Name);
			} else {
				outStr.AppendF("</{}>", node.Name);
			}
		}

		public static void EscapeStr(String value)
		{
			XmlAttribute.EscapeStr(value);
			value.Replace("'", "&apos;");
		}

#if DEBUG
		public void Test()
		{
			_root.ChildNodes.Add(.DocType)
				.SetText("html");

			XmlNode html = _root.AddChild("html")
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
		}
#endif
	}
}
