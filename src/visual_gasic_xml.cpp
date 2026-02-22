// VGXml — VB6-style XML document handling
// Uses Godot's XMLParser for reading and manual string building for writing

#include "visual_gasic_xml.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/xml_parser.hpp>

using namespace godot;

void VGXml::_bind_methods() {
    // Core methods
    ClassDB::bind_method(D_METHOD("load_file", "path"), &VGXml::load_file);
    ClassDB::bind_method(D_METHOD("load_string", "xml"), &VGXml::load_string);
    ClassDB::bind_method(D_METHOD("save_file", "path"), &VGXml::save_file);
    ClassDB::bind_method(D_METHOD("to_string"), &VGXml::to_string);
    ClassDB::bind_method(D_METHOD("parse"), &VGXml::parse);
    ClassDB::bind_method(D_METHOD("select_nodes", "path"), &VGXml::select_nodes);
    ClassDB::bind_method(D_METHOD("select_single_node", "path"), &VGXml::select_single_node);
    ClassDB::bind_static_method("VGXml", D_METHOD("from_dictionary", "dict", "root_name"), &VGXml::from_dictionary, DEFVAL("root"));
    ClassDB::bind_method(D_METHOD("get_last_error"), &VGXml::get_last_error);
    ClassDB::bind_method(D_METHOD("get_xml_content"), &VGXml::get_xml_content);
    ClassDB::bind_method(D_METHOD("set_xml_content", "xml"), &VGXml::set_xml_content);
    ClassDB::bind_static_method("VGXml", D_METHOD("escape_xml", "text"), &VGXml::escape_xml);
    ClassDB::bind_static_method("VGXml", D_METHOD("unescape_xml", "text"), &VGXml::unescape_xml);

    // VB6-style PascalCase aliases
    ClassDB::bind_method(D_METHOD("LoadFile", "path"), &VGXml::load_file);
    ClassDB::bind_method(D_METHOD("LoadString", "xml"), &VGXml::load_string);
    ClassDB::bind_method(D_METHOD("SaveFile", "path"), &VGXml::save_file);
    ClassDB::bind_method(D_METHOD("ToString"), &VGXml::to_string);
    ClassDB::bind_method(D_METHOD("Parse"), &VGXml::parse);
    ClassDB::bind_method(D_METHOD("SelectNodes", "path"), &VGXml::select_nodes);
    ClassDB::bind_method(D_METHOD("SelectSingleNode", "path"), &VGXml::select_single_node);
    ClassDB::bind_static_method("VGXml", D_METHOD("FromDictionary", "dict", "root_name"), &VGXml::from_dictionary, DEFVAL("root"));
    ClassDB::bind_static_method("VGXml", D_METHOD("EscapeXml", "text"), &VGXml::escape_xml);
    ClassDB::bind_static_method("VGXml", D_METHOD("UnescapeXml", "text"), &VGXml::unescape_xml);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "XmlContent"), "set_xml_content", "get_xml_content");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "LastError"), "", "get_last_error");
}

// ---------------------------------------------------------------------------
// Load / Save
// ---------------------------------------------------------------------------

bool VGXml::load_file(const String &p_path) {
    Ref<FileAccess> f = FileAccess::open(p_path, FileAccess::READ);
    if (!f.is_valid()) {
        last_error = "Cannot open file: " + p_path;
        UtilityFunctions::printerr("[VGXml] ", last_error);
        return false;
    }
    xml_content = f->get_as_text();
    last_error = "";
    return true;
}

bool VGXml::load_string(const String &p_xml) {
    xml_content = p_xml;
    last_error = "";
    return true;
}

bool VGXml::save_file(const String &p_path) {
    Ref<FileAccess> f = FileAccess::open(p_path, FileAccess::WRITE);
    if (!f.is_valid()) {
        last_error = "Cannot write file: " + p_path;
        UtilityFunctions::printerr("[VGXml] ", last_error);
        return false;
    }
    f->store_string(xml_content);
    return true;
}

String VGXml::to_string() {
    return xml_content;
}

String VGXml::get_xml_content() const {
    return xml_content;
}

void VGXml::set_xml_content(const String &p_xml) {
    xml_content = p_xml;
}

String VGXml::get_last_error() const {
    return last_error;
}

// ---------------------------------------------------------------------------
// Parse — builds a nested Dictionary tree from XML
// ---------------------------------------------------------------------------

// Recursive helper: parse elements from XMLParser into a Dictionary
static Variant _parse_element(Ref<XMLParser> &p_parser) {
    Dictionary element;
    Dictionary attributes;

    String node_name = p_parser->get_node_name();

    // Collect attributes
    for (int i = 0; i < p_parser->get_attribute_count(); i++) {
        attributes[p_parser->get_attribute_name(i)] = p_parser->get_attribute_value(i);
    }
    if (attributes.size() > 0) {
        element["@attributes"] = attributes;
    }

    // Check if self-closing
    if (p_parser->is_empty()) {
        return element;
    }

    String text_content;
    Array children_order;
    Dictionary children_map;

    while (p_parser->read() == OK) {
        XMLParser::NodeType type = p_parser->get_node_type();

        if (type == XMLParser::NODE_ELEMENT) {
            String child_name = p_parser->get_node_name();
            Variant child_val = _parse_element(p_parser);

            if (children_map.has(child_name)) {
                // Multiple children with same name → convert to array
                Variant existing = children_map[child_name];
                if (existing.get_type() == Variant::ARRAY) {
                    Array arr = existing;
                    arr.push_back(child_val);
                } else {
                    Array arr;
                    arr.push_back(existing);
                    arr.push_back(child_val);
                    children_map[child_name] = arr;
                }
            } else {
                children_map[child_name] = child_val;
                children_order.push_back(child_name);
            }
        } else if (type == XMLParser::NODE_TEXT) {
            String text = p_parser->get_node_data().strip_edges();
            if (!text.is_empty()) {
                text_content += text;
            }
        } else if (type == XMLParser::NODE_CDATA) {
            text_content += p_parser->get_node_data();
        } else if (type == XMLParser::NODE_ELEMENT_END) {
            break;
        }
    }

    // If element has only text content and no children/attributes, return the string directly
    if (children_map.size() == 0 && attributes.size() == 0 && !text_content.is_empty()) {
        return text_content;
    }

    // Merge children into element dict
    Array child_keys = children_map.keys();
    for (int i = 0; i < child_keys.size(); i++) {
        element[child_keys[i]] = children_map[child_keys[i]];
    }

    if (!text_content.is_empty()) {
        element["#text"] = text_content;
    }

    return element;
}

Dictionary VGXml::parse() {
    Dictionary result;
    if (xml_content.is_empty()) {
        last_error = "No XML content loaded";
        return result;
    }

    Ref<XMLParser> parser;
    parser.instantiate();
    Error err = parser->open_buffer(xml_content.to_utf8_buffer());
    if (err != OK) {
        last_error = "Failed to open XML buffer";
        UtilityFunctions::printerr("[VGXml] ", last_error);
        return result;
    }

    while (parser->read() == OK) {
        if (parser->get_node_type() == XMLParser::NODE_ELEMENT) {
            String name = parser->get_node_name();
            Variant val = _parse_element(parser);
            result[name] = val;
        }
    }

    last_error = "";
    return result;
}

// ---------------------------------------------------------------------------
// SelectNodes — simplified path selection (e.g., "root/child/element")
// ---------------------------------------------------------------------------

static void _collect_at_path(const Variant &p_node, const PackedStringArray &p_parts, int p_depth, Array &r_results) {
    if (p_depth >= p_parts.size()) {
        r_results.push_back(p_node);
        return;
    }

    if (p_node.get_type() != Variant::DICTIONARY) {
        return;
    }

    Dictionary dict = p_node;
    String key = p_parts[p_depth];

    if (!dict.has(key)) return;

    Variant child = dict[key];
    if (child.get_type() == Variant::ARRAY) {
        Array arr = child;
        for (int i = 0; i < arr.size(); i++) {
            _collect_at_path(arr[i], p_parts, p_depth + 1, r_results);
        }
    } else {
        _collect_at_path(child, p_parts, p_depth + 1, r_results);
    }
}

Array VGXml::select_nodes(const String &p_path) {
    Array results;
    Dictionary tree = parse();
    if (tree.is_empty()) return results;

    PackedStringArray parts = p_path.split("/", false);
    if (parts.size() == 0) return results;

    _collect_at_path(tree, parts, 0, results);
    return results;
}

Variant VGXml::select_single_node(const String &p_path) {
    Array nodes = select_nodes(p_path);
    if (nodes.size() > 0) return nodes[0];
    return Variant();
}

// ---------------------------------------------------------------------------
// FromDictionary — build XML string from a Dictionary
// ---------------------------------------------------------------------------

static String _dict_to_xml(const Variant &p_value, const String &p_tag, int p_indent) {
    String indent;
    for (int i = 0; i < p_indent; i++) {
        indent += "  ";
    }

    if (p_value.get_type() == Variant::DICTIONARY) {
        Dictionary dict = p_value;
        String xml = indent + "<" + p_tag;

        // Handle @attributes
        if (dict.has("@attributes")) {
            Dictionary attrs = dict["@attributes"];
            Array attr_keys = attrs.keys();
            for (int i = 0; i < attr_keys.size(); i++) {
                xml += " " + String(attr_keys[i]) + "=\"" + VGXml::escape_xml(String(attrs[attr_keys[i]])) + "\"";
            }
        }

        // Gather child elements (skip @attributes and #text)
        Array keys = dict.keys();
        bool has_children = false;
        for (int i = 0; i < keys.size(); i++) {
            String k = keys[i];
            if (k != "@attributes" && k != "#text") {
                has_children = true;
                break;
            }
        }

        String text_content;
        if (dict.has("#text")) {
            text_content = String(dict["#text"]);
        }

        if (!has_children && text_content.is_empty()) {
            xml += " />\n";
            return xml;
        }

        xml += ">";
        if (has_children) {
            xml += "\n";
        }

        for (int i = 0; i < keys.size(); i++) {
            String k = keys[i];
            if (k == "@attributes" || k == "#text") continue;

            Variant child = dict[k];
            if (child.get_type() == Variant::ARRAY) {
                Array arr = child;
                for (int j = 0; j < arr.size(); j++) {
                    xml += _dict_to_xml(arr[j], k, p_indent + 1);
                }
            } else {
                xml += _dict_to_xml(child, k, p_indent + 1);
            }
        }

        if (!text_content.is_empty()) {
            if (has_children) {
                xml += indent + "  " + VGXml::escape_xml(text_content) + "\n";
                xml += indent + "</" + p_tag + ">\n";
            } else {
                xml += VGXml::escape_xml(text_content) + "</" + p_tag + ">\n";
            }
        } else {
            xml += indent + "</" + p_tag + ">\n";
        }

        return xml;
    } else if (p_value.get_type() == Variant::ARRAY) {
        String xml;
        Array arr = p_value;
        for (int i = 0; i < arr.size(); i++) {
            xml += _dict_to_xml(arr[i], p_tag, p_indent);
        }
        return xml;
    } else {
        // Scalar value
        return indent + "<" + p_tag + ">" + VGXml::escape_xml(String(p_value)) + "</" + p_tag + ">\n";
    }
}

String VGXml::from_dictionary(const Dictionary &p_dict, const String &p_root_name) {
    String xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    xml += _dict_to_xml(p_dict, p_root_name, 0);
    return xml;
}

// ---------------------------------------------------------------------------
// Utility: escape/unescape XML
// ---------------------------------------------------------------------------

String VGXml::escape_xml(const String &p_text) {
    String result = p_text;
    result = result.replace("&", "&amp;");
    result = result.replace("<", "&lt;");
    result = result.replace(">", "&gt;");
    result = result.replace("\"", "&quot;");
    result = result.replace("'", "&apos;");
    return result;
}

String VGXml::unescape_xml(const String &p_text) {
    String result = p_text;
    result = result.replace("&lt;", "<");
    result = result.replace("&gt;", ">");
    result = result.replace("&quot;", "\"");
    result = result.replace("&apos;", "'");
    result = result.replace("&amp;", "&");
    return result;
}
