// VGXml — VB6-style XML document handling
// Wraps Godot's XMLParser for reading and manual string-building for writing
//
// Usage in VisualGasic:
//   ' Load and parse XML
//   Dim xml As New XmlDocument
//   xml.LoadFile "res://data/config.xml"
//   Dim tree As Dictionary
//   tree = xml.Parse()
//   Print tree("root")("settings")("volume")
//
//   ' Select nodes with simplified path
//   Dim nodes As Array
//   nodes = xml.SelectNodes("root/settings/item")
//
//   ' Create XML from Dictionary
//   Dim dict As New Dictionary
//   dict("name") = "Alice"
//   dict("age") = 30
//   Dim result As String
//   result = XmlDocument.FromDictionary(dict, "user")
//
//   ' Save to file
//   xml.LoadString result
//   xml.SaveFile "user://output.xml"

#ifndef VISUAL_GASIC_XML_H
#define VISUAL_GASIC_XML_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

class VGXml : public RefCounted {
    GDCLASS(VGXml, RefCounted);

    String xml_content;
    String last_error;

protected:
    static void _bind_methods();

public:
    // Load/Save
    bool load_file(const String &p_path);
    bool load_string(const String &p_xml);
    bool save_file(const String &p_path);
    String to_string();

    // Parse to Dictionary tree
    Dictionary parse();

    // XPath-style select (simplified path like "root/child/element")
    Array select_nodes(const String &p_path);
    Variant select_single_node(const String &p_path);

    // Create XML from Dictionary
    static String from_dictionary(const Dictionary &p_dict, const String &p_root_name = "root");

    // Utility
    String get_last_error() const;
    String get_xml_content() const;
    void set_xml_content(const String &p_xml);
    static String escape_xml(const String &p_text);
    static String unescape_xml(const String &p_text);
};

#endif // VISUAL_GASIC_XML_H
