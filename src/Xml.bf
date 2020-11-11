using System;
using System.Collections;
using System.IO;
using System.Text;

/*
** This lib was heavilly inspired by VerySimpleXml
** https://github.com/Dennis1000/verysimplexml/blob/master/Source/Xml.VerySimple.pas
** Credits for the original sources go to the original developer.
**
** I (Thibmo) only ported this lib to pure BeefLang 
*/

namespace Xml_Beef
{
	enum XmlNodeType
	{
		None                  = 0x0000,
		Element               = 0x0001,
		Attribute             = 0x0002,
		Text                  = 0x0004,
		CDataSection          = 0x0008,
		EntityReference       = 0x0010,
		Entity                = 0x0020,
		ProcessingInstruction = 0x0040,
		Comment               = 0x0080,
		Document              = 0x0100,
		DocType               = 0x0200,
		DocumentFragment      = 0x0400,
		Notation              = 0x0800,
		XmlDecl               = 0x1000
	}

	public enum XmlAttrType
	{
		Value,
		Flag
	}

	public enum XmlOption
	{
		None                       = 0x0000,
		NodeAutoIndent             = 0x0001,
		Compact                    = 0x0002,
		ParseProcessingInstruction = 0x0004,
		PreserveWhiteSpace         = 0x0008,
		CaseInsensitive            = 0x0010,
		WriteBOM                   = 0x0020
	}

	public enum XmlExtractTextOption
	{
		None           = 0x0000,
		DeleteStopChar = 0x0001,
		StopString     = 0x0002
	}

	class XmlStreamReader : StreamReader
	{
		String buffStr = new .() ~ delete _;

		public this() { }

		[AllowAppend]
		public this(Stream stream, Encoding encoding, bool detectBOM, int32 bufferSize, bool ownsSteam = false) :
			base(stream, encoding, detectBOM, bufferSize, ownsSteam) { }

		[AllowAppend]
		public this(Stream stream) : base(stream, .UTF8, false, 4096) { }

		public new bool EndOfStream
		{
			get { return base.EndOfStream && buffStr.Length == 0; }
		}

		void FillBuffer()
		{
			if (buffStr.Length >= [Friend]mMaxCharsPerBuffer)
				return;

			int remainder = ([Friend]mCharLen) - [Friend]mCharPos;
			int toCopy;

			if (remainder > 0) {
				toCopy = Math.Min(remainder, ([Friend]mMaxCharsPerBuffer) - buffStr.Length);
				buffStr.Append([Friend]mCharBuffer, [Friend]mCharPos, toCopy);
				*(&[Friend]mCharPos) += toCopy;
			}

			toCopy = ([Friend]mMaxCharsPerBuffer) - buffStr.Length;

			if (toCopy <= 0)
				return;

			toCopy = Math.Min(TrySilent!(ReadBuffer()), toCopy);

			if (toCopy <= 0)
				return;

			buffStr.Append([Friend]mCharBuffer, [Friend]mCharPos, toCopy);
			*(&[Friend]mCharPos) += toCopy;
		}

		// Assures the read buffer holds at least Value characters
		public bool PrepareBuffer(int val)
		{
			if (buffStr == null)
				return false;

			if (buffStr.Length < val && base.EndOfStream)
				FillBuffer();

			return buffStr.Length >= val;
		}

		// Extract text until chars found in StopChars
		public void ReadText(String outStr, String stopChars, XmlExtractTextOption options)
		{
			outStr.Clear();

			if (buffStr == null)
				return;
			
			int tmpIdx = 0;
			int newLineIdx = 0;
			int postNewLineIdx = 0;
			int stopCharLen = stopChars.Length;
			int prevLen = 0;
			bool found = false;

			while (true) {
				if (options.HasFlag(.StopString) && newLineIdx + stopCharLen > buffStr.Length && !base.EndOfStream)
					FillBuffer();

				if (newLineIdx >= buffStr.Length) {
					if (base.EndOfStream) {
						postNewLineIdx = newLineIdx;
						break;
					} else {
						prevLen = buffStr.Length;
						FillBuffer();

						// Break if no more data
						if (buffStr.Length == 0 || buffStr.Length == prevLen)
							break;
					}
				}

				if (options.HasFlag(.StopString)) {
					if (newLineIdx + stopCharLen - 1 < buffStr.Length) {
						found = true;
						tmpIdx = newLineIdx;

						for (int i = 0; i < stopCharLen; i++) {
							if (buffStr[tmpIdx] != stopChars[i]) {
								found = false;
								break;
							} else {
								tmpIdx++;
							}
						}

						if (found) {
							postNewLineIdx = newLineIdx;

							if (options.HasFlag(.DeleteStopChar))
								postNewLineIdx += stopCharLen;

							break;
						}
					}
				} else {
					found = false;

					for (int i = 0; i < stopCharLen; i++) {
						if (buffStr[newLineIdx] == stopChars[i]) {
							postNewLineIdx = newLineIdx;

							if (options.HasFlag(.DeleteStopChar))
								postNewLineIdx++;

							found = true;
							break;
						}
					}

					if (found)
						break;
				}

				newLineIdx++;
			}

			if (newLineIdx > 0)
				outStr.Append(buffStr.Ptr, newLineIdx);

			buffStr.Remove(0, postNewLineIdx);
		}

		// Returns fist char but does not removes it from the buffer
		public void FirstChar(String outStr)
		{
			outStr.Clear();

			if (PrepareBuffer(1))
				outStr.Append(buffStr[0]);
		}

		// Proceed with the next character(s) (value optional, default 1)
		public void IncCharPos(int val = 1)
		{
			if (PrepareBuffer(val))
				buffStr.Remove(0, val);
		}

		// Returns True if the first upper-cased characters at the current position match Value
		public bool IsUppercaseText(String val)
		{
			int valLen = val.Length;
			String tmp = scope:: .();

			if (PrepareBuffer(valLen)) {
				tmp.Append(buffStr.Ptr, valLen);

				if (tmp.Equals(val, .Ordinal)) {
					buffStr.Remove(0, valLen);
					return true;
				}
			}

			return false;
		}
	}

	public class XmlAttribute
	{
		public XmlAttrType AttrType = .Flag;

		String _name = new .() ~ delete _;
		public String Name
		{
			get { return _name; }
			set { _name.Set(value); }
		}

		String _value = new .() ~ delete _;
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
		Xml _document = null;
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
		// All the attributes of this node
		public readonly XmlAttributeList AttributeList;
		
		// List of child nodes, never null
		public readonly XmlNodeList ChildNodes;

		// The node type, see TXmlNodeType
		public XmlNodeType NodeType;
		
		// The xml document that this node belongs to
		Xml _document = null;
		public Xml Document
		{
			get { return _document; }
			set { _document = AttributeList.Document = ChildNodes.Document = value; }
		}

		// Parent node, may be null
		XmlNode _parent = null;
		public XmlNode Parent
		{
			get { return _parent; }
			set { _parent = value; }
		}

		// Name of the node
		String _name = new .() ~ delete _;
		public String Name
		{
			get { return _name; }
			set { _name.Set(value); }
		}

		// Text value of the node
		String _text = new .() ~ delete _;
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
		public XmlNode Find(String name, String attrName, XmlNodeType types = .Element) =>
			ChildNodes.Find(name, attrName, types);

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
		public XmlNode SetName(String val)
		{
			_name.Set(val);
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
		public XmlNode SetAttribute(String name, String val)
		{
			XmlAttribute attr = AttributeList.Find(name);

			if (attr == null)
				attr = AttributeList.Add(name);

			attr.AttrType = .Value;
			attr.Name = name;
			attr.Value = val;
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
		Xml _document;
		public Xml Document
		{
			get { return _document; }
			set { _document = value; }
		}

		XmlNode _parent;
		public XmlNode Parent
		{
			get { return _parent; }
			set { _parent = value; }
		}

		
		// Adds a node and sets the parent of the node to the parent of the list
		public new int Add(XmlNode val)
		{
			val.Parent = _parent;
			base.Add(val);
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
		// 0x20 (' '), 0x0A ('\n'), 0x0D ('\r') and 0x09 ('\t') ordered by most commonly used, to speed searches up
		private static readonly char8[] CXmlSpaces = new .('\x20', '\x0A', '\x0D', '\x09') ~ delete _;

		XmlNode _root = null;
		XmlNode _header = null;
		XmlNode _documentElement = null;
		bool _skipIndent = false;

		public String LineBreak = new .(Environment.NewLine) ~ delete _;
		public XmlOption Options = .NodeAutoIndent | .WriteBOM;
		
		// A list of all root nodes of the document
		public XmlNodeList ChildNodes
		{
			get { return _root.ChildNodes; }
		}

		// Returns the first element node
		public XmlNode DocumentElement
		{
			get { return _documentElement; }
			set
			{
				_documentElement = value;

				if (value.Parent == null)
					_root.ChildNodes.Add(value);
			}
		}

		// XML declarations are stored in here as Attributes
		public XmlNode Header
		{
			get { return _header; }
		}

		// Set to True if all spaces and linebreaks should be included as a text node, same as doPreserve option
		public bool PreserveWhitespace
		{
			get { return Options.HasFlag(.PreserveWhiteSpace); }
			set
			{
				if (value) {
					Options |= .PreserveWhiteSpace;
				} else {
					Options &= ~.PreserveWhiteSpace;
				}
			}
		}

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
			_root.Parent = null;
			Clear();
			delete _root;

			if (_header != null)
				delete _header;

			if (_documentElement != null)
				delete _documentElement;
		}

		private void Parse(XmlStreamReader reader)
		{
			Clear();
			XmlNode parent = _root;
			String line = scope:: .();

			while (!reader.EndOfStream) {
				line.Clear();
				reader.ReadText(line, "<", .DeleteStopChar);

				if (!String.IsNullOrWhiteSpace(line)) { // Check for text nodes
					ParseText(line, parent);

					// if no chars available then exit
					if (reader.EndOfStream)
						break;
				}

				String firstChar = scope:: .();
				reader.FirstChar(firstChar);

				if (firstChar.Equals("!")) {
					if (reader.IsUppercaseText("!--")) {  // check for a comment node
						ParseComment(reader, ref parent);
					} else if (reader.IsUppercaseText("!DOCTYPE")) { // check for a doctype node
						ParseDocType(reader, ref parent);
					} else if (reader.IsUppercaseText("![CDATA[")) { // check for a cdata node
						ParseCData(reader, ref parent);
					} else { // try to parse as tag
						ParseTag(reader, false, ref parent);
					} 
				} else { // Check for XML header / processing instructions
					if (firstChar.Equals("?")) { // could be header or processing instruction
						ParseProcessingInstr(reader, ref parent);
					} else if (firstChar.Length != 0) { // Parse a tag, the first tag in a document is the DocumentElement
						XmlNode node = ParseTag(reader, true, ref parent);

						if (_documentElement == null && parent == _root)
							_documentElement = node;
					}
				}
			}
		}

		private void ParseComment(XmlStreamReader reader, ref XmlNode parent)
		{
			XmlNode node = parent.ChildNodes.Add(.Comment);
			reader.ReadText(node.Text, "-->", .DeleteStopChar | .StopString);
		}

		private void ParseDocType(XmlStreamReader reader, ref XmlNode parent)
		{
			XmlNode node = parent.ChildNodes.Add(.DocType);
			reader.ReadText(node.Text, ">[", .None);

			if (!reader.EndOfStream) {
				String quote = scope:: .();
				reader.FirstChar(quote);
				reader.IncCharPos();

				if (quote.Equals("[")) {
					String tmp = scope:: .();

					reader.ReadText(node.Text, "]", .DeleteStopChar);
					node.Text.AppendF("{}{}", quote, tmp);

					reader.ReadText(node.Text, ">", .DeleteStopChar);
					node.Text.AppendF("]{}", tmp);
				}
			}
		}

		private void ParseProcessingInstr(XmlStreamReader reader, ref XmlNode parent)
		{
			reader.IncCharPos(); // omit the '?'
			String tag = scope:: .();
			reader.ReadText(tag, "?>", .DeleteStopChar | .StopString);
			XmlNode node = ParseTag(tag, ref parent);

			if (node.Name.Equals("xml", .OrdinalIgnoreCase)) {
				_header = node;
				_header.NodeType = .XmlDecl;
			} else {
				node.NodeType = .ProcessingInstruction;

				if (!Options.HasFlag(.ParseProcessingInstruction)) {
					node.Text = tag;
					DeleteAndClearItems!(node.AttributeList);
				}
			}

			parent = node.Parent;
		}

		private void ParseCData(XmlStreamReader reader, ref XmlNode parent)
		{
			XmlNode node = parent.ChildNodes.Add(.CDataSection);
			reader.ReadText(node.Text, "]]>", .DeleteStopChar | .StopString);
		}

		private void ParseText(String line, XmlNode parent)
		{
			bool textNode;

			if (PreserveWhitespace) {
				textNode = true;
			} else {
				textNode = false;

				if (line.IndexOfAny(CXmlSpaces) > -1)
					textNode = true;
			}

			if (textNode)
				parent.ChildNodes.Add(.Text)
					.Text = line;
		}

		private XmlNode ParseTag(XmlStreamReader reader, bool parseText, ref XmlNode parent)
		{
			String tag = scope:: .();
			reader.ReadText(tag, ">", .DeleteStopChar);
			XmlNode node = ParseTag(tag, ref parent);

			if (node == parent && parseText) { // only non-self closing nodes may have a text
				String line = scope:: .();
				reader.ReadText(line, "<", .None);
				UnescapeStr(line);
				
				if (PreserveWhitespace) {
					node.Text = line;
				} else {
					bool found = false;

					for (int i = 0; i < line.Length; i++) {
						for (char8 char in CXmlSpaces) {
							if (line[i] == char) {
								found = true;
								break;
							}
						}

						if (!found) {
							node.Text = line;
							break;
						}
					}
				}
			}

			return node;
		}

		private XmlNode ParseTag(String tagStr, ref XmlNode parent)
		{
			XmlNode node;

			// A closing tag does not have any attributes nor text
			if (tagStr.Length > 0 && tagStr.StartsWith('/')) {
				node = parent;
				parent = parent.Parent;
				return node;
			}
			
			// Create a new new .Element node
			node = parent.ChildNodes.Add();
			String tag = scope:: .(tagStr);

			if (tag.Length > 0 && tag.EndsWith('/')) {
				tag.RemoveFromEnd(1);
			} else {
				parent = node;
			}

			int charPos = tag.IndexOf(' ');

			if (charPos > -1) { // Tag may have attributes
				String line = scope:: .();
				line.Append(tag, charPos);
				tag.RemoveToEnd(charPos);

				if (line.Length > 0)
					ParseAttributes(line, node.AttributeList);
			}

			node.Name = tag;
			return node;
		}

		// Parse attributes into the attribute list for a given string
		public void ParseAttributes(String attribStr, XmlAttributeList attributeList)
		{
			String value = scope:: .(attribStr);
			value.TrimStart();

			while (value.Length > 0) {
				String attrName = scope:: .();
				ExtractText(attrName, value, "= ", .None);
				value.TrimStart();
				XmlAttribute attr = attributeList.Add(attrName);

				if (value.Length == 0 || !value.StartsWith('='))
					continue;

				value.Remove(0);
				attr.AttrType = .Value;
				String dummy = scope:: .();
				ExtractText(dummy, value, "'\"", .None);
				value.TrimStart();

				if (value.Length > 0) {
					String quote = scope:: .(value, 0, 1);
					value.Remove(0);
					ExtractText(attr.Value, value, quote, .DeleteStopChar); // Get Attribute Value
					UnescapeStr(attr.Value);
					value.TrimStart();
				}
			}
		}

		private void Compose(StreamWriter writer)
		{
			if (Options.HasFlag(.Compact))
				LineBreak.Clear();

			_skipIndent = false;

			for (XmlNode child in _root.ChildNodes)
				Walk(writer, "", child);
		}

		private void Walk(StreamWriter writer, StringView prefix, XmlNode node)
		{
			if ((node == _root.ChildNodes.Front) || (_skipIndent)) {
				writer.Write("<");
				_skipIndent = false;
			} else {
				writer.Write("{}{}{}", LineBreak, prefix, '<');
			}

			switch (node.NodeType)
			{
				case .Comment:
				{
					writer.Write("!--{}-->", node.Text);
					return;
				}
				case .DocType:
				{
					writer.Write("!DOCTYPE {}>", node.Text);
					return;
				}
				case .CDataSection:
				{
					writer.Write("<![CDATA[{}]]>", node.Text);
					return;
				}
				case .Text:
				{
					writer.Write(node.Text);
					_skipIndent = true;
					return;
				}
				case .ProcessingInstruction:
				{
					if (node.AttributeList.Count > 0) {
						String tmp = scope:: .();
						node.AttributeList.AsString(tmp);
						writer.Write("?{}{}?>", node.Name, tmp);
					} else {
						writer.Write("?{}?>", node.Text);
					}

					return;
				}
				case .XmlDecl:
				{
					String tmp = scope:: .();
					node.AttributeList.AsString(tmp);
					writer.Write("?{}{}?>", node.Name, tmp);
					return;
				}
				default: {}
			}

			String tmp = scope:: .();
			node.AttributeList.AsString(tmp);
			writer.Write("{}{}", node.Name, tmp);

			// Self closing tags
			if (String.IsNullOrWhiteSpace(node.Text) && !node.HasChildNodes) {
				writer.Write("/>");
				return;
			}

			writer.Write(">");

			if (!String.IsNullOrWhiteSpace(node.Text)) {
				tmp.Set(node.Text);
				EscapeStr(tmp);
				writer.Write(tmp);

				if (node.HasChildNodes)
					_skipIndent = true;
			}

			// Set indent for child nodes
			String indent = scope:: .();

			if (!Options.HasFlag(.Compact))
				indent.AppendF("{}  ", prefix);

			// Process child nodes
			for (XmlNode child in node.ChildNodes)
				Walk(writer, indent, child);

			if (node.HasChildNodes && !_skipIndent) {
				writer.Write("{}{}</{}>", LineBreak, prefix, node.Name);
			} else {
				writer.Write("</{}>", node.Name);
			}
		}

		public void SetText(String val) => LoadFromString(val);

		public void GetText(String outStr) => SaveToString(outStr);

		public void SetEncoding(String val)
		{
			CreateHeaderNode();
			_header["encoding"] = val;
		}

		public void GetEncoding(String outStr)
		{
			outStr.Clear();

			if (_header != null)
				outStr.AppendF(_header["encoding"]);
		}

		public void SetVersion(String val)
		{
			CreateHeaderNode();
			_header["version"] = val;
		}

		public void GetVersion(String outStr)
		{
			outStr.Clear();

			if (_header != null)
				outStr.AppendF(_header["version"]);
		}

		public void SetStandAlone(String val)
		{
			CreateHeaderNode();
			_header["standalone"] = val;
		}

		public void GetStandAlone(String outStr)
		{
			outStr.Clear();

			if (_header != null)
				outStr.AppendF(_header["standalone"]);
		}

		private void CreateHeaderNode()
		{
			if (_header != null)
				return;

			_header = new .();
			_header["version"] = "1.0";
			_header["encoding"] = "utf-8";
		}

		private void ExtractText(String outStr, String line, String stopChars, XmlExtractTextOption options)
		{
			int foundPos = -1;
			int charPos;

			for (int i = 0; i < stopChars.Length; i++) {
				charPos = line.IndexOf(stopChars[i]);

				if (charPos > -1 && (foundPos == -1 || charPos < foundPos))
					foundPos = charPos;
			}

			if (foundPos > -1) {
				outStr.Clear();
				outStr.Append(line, 0, foundPos);

				if (options.HasFlag(.DeleteStopChar))
					foundPos++;

				line.Remove(0, foundPos);
			} else {
				outStr.Set(line);
				line.Clear();
			}
		}

		// Deletes all nodes
		public void Clear()
		{
			if (_header != null && _header.Parent == null)
				delete _header;
			
			_header = null;
			_documentElement = null; // Always owned by a parent, just unref
			_root.Clear();
		}

		// Adds a new node to the document, if it's the first ntElement then sets it as .DocumentElement
		public XmlNode AddChild(String name, XmlNodeType type = .Element)
		{
			XmlNode node = CreateNode(name, type);

			if (type == .Element && _documentElement != null)
				_documentElement = node;

			_root.ChildNodes.Add(node);
			node.Document = this;
			return node;
		}

		// Creates a new node but doesn't adds it to the document nodes
		public XmlNode CreateNode(String name, XmlNodeType type = .Element)
		{
			XmlNode node = new .(type);
			node.Name = name;
			node.Document = this;
			return node;
		}

		// Loads the XML from a stream
		public Xml LoadFromStream(Stream stream, int32 buffSize = 4096)
		{
			XmlStreamReader reader;

			if (_header["encoding"].IsEmpty) { // none specified then use UTF8 with DetectBom
				reader = new .(stream, .UTF8, true, buffSize);
			} else if (_header["encoding"].Equals("utf-8", .OrdinalIgnoreCase)) {
				reader = new .(stream, .UTF8, false, buffSize);
			} else {
				reader = new .(stream, .ASCII, false, buffSize);
			}

			Parse(reader);
			delete reader;
			return this;
		}

		// Loads the XML from a file
		public Xml LoadFromFile(String fileName, int32 buffSize = 4096)
		{
			FileStream stream = new .();

			if (stream.Open(fileName, .Read, .None) == .Ok) {
				LoadFromStream(stream, buffSize);
				stream.Close();
			}

			delete stream;
			return this;
		}
		
		// Loads the XML from a string
		public Xml LoadFromString(String val, int32 buffSize = 4096)
		{
			StringStream stream = new .(val, .Copy);

			if (stream.Seek(0, .Absolute) == .Ok && stream.Length > 0)
				LoadFromStream(stream, buffSize);

			delete stream;
			return this;
		}

		// Saves the XML to a stream, the encoding is specified in the .Encoding property
		public Xml SaveToStream(Stream stream)
		{
			StreamWriter writer;

			if (_header["encoding"].Equals("utf-8", .OrdinalIgnoreCase)) {
				writer = new .(stream, .UTF8, 4096);
			} else {
				writer = new .(stream, .ASCII, 4096);
			}

			Compose(writer);
			delete writer;
			return this;
		}

		// Saves the XML to a file
		public Xml SaveToFile(String fileName)
		{
			FileStream stream = new .();

			if (stream.Create(fileName, .Write, .None) == .Ok) {
				SaveToStream(stream);
				stream.Close();
			}

			delete stream;
			return this;
		}

		public Xml SaveToString(String outStr)
		{
			StringStream stream = new .();
			SaveToStream(stream);
			outStr.Set(stream.Content);
			delete stream;
			return this;
		}
		
		// Escapes XML control characters
		public static void EscapeStr(String val)
		{
			XmlAttribute.EscapeStr(val);
			val.Replace("'", "&apos;");
		}

		[Inline]
		public static void EscapeStr(StringView inStr, String outStr)
		{
			outStr.Set(inStr);
			EscapeStr(outStr);
		}

		// Translates escaped characters back into XML control characters
		public static void UnescapeStr(String val)
		{
  			val.Replace("&lt;", "<");
  			val.Replace("&gt;", ">");
  			val.Replace("&quot;", "\"");
  			val.Replace("&apos;", "'");
  			val.Replace("&amp;", "&");
		}

		[Inline]
		public static void UnescapeStr(StringView inStr, String outStr)
		{
			outStr.Set(inStr);
			UnescapeStr(outStr);
		}
	}
}
