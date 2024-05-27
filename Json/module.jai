#module_parameters () (JSON_DEBUG := false) {};

JsonKind :: enum {
    ERROR;
    NULL;
    BOOL;
    NUMBER_INT;
    NUMBER_FLOAT;
    STRING;
    OBJECT;
    ARRAY;
};

JsonNode :: struct {
    kind : JsonKind;
    using raw_value : JsonValue;
}

JsonValue :: union {
    err : string; // JsonKind.ERROR
    bol : bool; // JsonKind.BOOL
    num_int : s64; // JsonKind.NUMBER_INT
    num_float : float64; // JsonKind.NUMBER_FLOAT
    str : string; // JsonKind.STRING
    obj : [..]JsonObjectBody; // JsonKind.OBJECT
    arr : [..]JsonNode; // JsonKind.ARRAY
};

JsonObjectBody :: struct {
    key : string;
    value : JsonNode;
}

json_parse :: (json: string, result: *JsonNode) -> int {
    end_index := json_parse_value(json, 0, result);
    if end_index >= 0 && end_index != json.count {
        #if JSON_DEBUG print("json_parse() - % != %\n", end_index, json.count);
        return set_error(result, "Unexpected end of JSON.");
    }
    return end_index;
}

json_parse_value :: (json: string, start_index : int, result: *JsonNode) -> end_index: int {
    #if JSON_DEBUG print("json_parse_value(%);\n", substring(json, start_index));
    i := start_index;
    while true {
        i = eat_white_spaces(json, i);
        if i >= json.count {
            return set_error(result, "Expected a value but reached end of string");
        }

        if json[i] == {
            case #char "\"";
                node_end, str := json_parse_string(json, i + 1);
                result.kind = .STRING;
                result.str = str;
                return ifx node_end < 0 then node_end else eat_white_spaces(json, node_end);
            case #char "{";
                node_end := json_parse_object(json, i + 1, result);
                return ifx node_end < 0 then node_end else eat_white_spaces(json, node_end);
            case #char "[";
                node_end := json_parse_array(json, i + 1, result);
                return ifx node_end < 0 then node_end else eat_white_spaces(json, node_end);
            case #char "t";
                if (i + 3 < json.count &&
                    json[i+1] == #char "r" &&
                    json[i+2] == #char "u" &&
                    json[i+3] == #char "e") {
                    result.kind = .BOOL;
                    result.bol = true;
                    node_end := i + 4;
                    return ifx node_end < 0 then node_end else eat_white_spaces(json, node_end);
                }
                return set_error(result, "Expected a value but got \"t\".");
            case #char "f";
                if (i + 4 < json.count &&
                    json[i+1] == #char "a" &&
                    json[i+2] == #char "l" &&
                    json[i+3] == #char "s" &&
                    json[i+4] == #char "e") {
                    result.kind = .BOOL;
                    result.bol = false;
                    node_end := i + 5;
                    return ifx node_end < 0 then node_end else eat_white_spaces(json, node_end);
                }
                return set_error(result, "Expected a value but got \"f\".");
            case #char "n";
                if (i + 3 < json.count &&
                    json[i+1] == #char "u" &&
                    json[i+2] == #char "l" &&
                    json[i+3] == #char "l") {
                    result.kind = .NULL;
                    result.raw_value = .{};
                    node_end := i + 4;
                    return ifx node_end < 0 then node_end else eat_white_spaces(json, node_end);
                }
                return set_error(result, "Expected a value but got \"n\".");
            case #char "-"; #through;
            case #char "0"; #through;
            case #char "1"; #through;
            case #char "2"; #through;
            case #char "3"; #through;
            case #char "4"; #through;
            case #char "5"; #through;
            case #char "6"; #through;
            case #char "7"; #through;
            case #char "8"; #through;
            case #char "9";
                node_end := json_parse_number(json, i, result);
                return ifx node_end < 0 then node_end else eat_white_spaces(json, node_end);
            case;
                return set_error(result, "Expected a value but got some unexpected character.");
        }
    }
    return set_error(result);
}

json_parse_number :: (json: string, start_index: int, result: *JsonNode) -> end_index: int {
    handle_float :: () -> int #expand {
        `result.kind = .NUMBER_FLOAT;
        r, success := string_to_float64(substring(`json, `start_index, `i));
        if !success return set_error(result, "Failed to parse number as float");
        `result.num_float = r;
        return `i;
    };
    #if JSON_DEBUG print("json_parse_number(%);\n", substring(json, start_index));
    i := start_index;
    if i >= json.count return set_error(result, "Expected a number but reached end of string");
    // Optional "-"
    if json[i] == #char "-" {
        i += 1;
        if i >= json.count return set_error(result, "Expected a digit after \"-\" but reached end of string");
    }
    // "0", or "1" followed by digits
    if json[i] == #char "0" {
        i += 1;
    } else if json[i] >= #char "1" || json[i] <= #char "9" {
        i += 1;
        while true {
            if i >= json.count {
                result.kind = .NUMBER_INT;
                result.num_int = to_integer(substring(json, start_index, i));
                return i;
            }
            if !is_digit(json[i]) break;
            i += 1;
        }
    } else {
        return set_error(result, "Expected a digit after \"-\" but got some other character");
    }
    // Optional "."
    if i >= json.count || json[i] != #char "." {
        result.kind = .NUMBER_INT;
        result.num_int = to_integer(substring(json, start_index, i));
        return i;
    }
    i += 1;
    // Fraction
    while true {
        if i >= json.count return handle_float();
        if !is_digit(json[i]) break;
        i += 1;
    }
    // Optional "e" / "E"
    if json[i] != #char "e" && json[i] != #char "E" {
        return handle_float();
    }
    i += 1;
    // Exponent
    while true {
        if i >= json.count return handle_float();
        if !is_digit(json[i]) break;
        i += 1;
    }
    return handle_float();
}

json_parse_string :: (json: string, start_index: int) -> end_index: int, result: string {
    #if JSON_DEBUG print("json_parse_string(%);\n", substring(json, start_index));
    i := start_index;
    while true {
        if i >= json.count {
            return -1, "Unexpected end of string";
        }

        if json[i] == {
            case; // Normal code point
                i += 1; // @TODO Read bytes as utf8
            case #char "\\"; // Escape character
                if json[i+1] == {
                    case #char "\\"; #through;
                    case #char "\""; #through;
                    case #char "/";  #through;
                    case #char "b";  #through;
                    case #char "f";  #through;
                    case #char "n";  #through;
                    case #char "r";  #through;
                    case #char "t";
                        i += 2;
                    case #char "u";
                        if !is_hex(json[i+2]) ||
                           !is_hex(json[i+3]) ||
                           !is_hex(json[i+4]) ||
                           !is_hex(json[i+5]) {
                            return -1, "Unexpected end of escaped unicode";
                        }
                        i += 6;
                    case;
                        return -1, "Unexpected escaped character";
                }
            case #char "\""; // End of string
                result : string;
                result.data = *json[start_index];
                result.count = i - start_index;
                return i + 1, result;
        }
    }
    return -1, "wtf?";
}

json_parse_object :: (json: string, start_index: int, result: *JsonNode) -> end_index: int {
    // @LEAK This leaks any assigned members of the object if it fails after assigning them!
    #if JSON_DEBUG print("json_parse_object(%);\n", substring(json, start_index));
    result.kind = .OBJECT;
    i := start_index;
    expect_comma := false;
    trailing_comma := false;
    while true {
        #if JSON_DEBUG print("LOOP json_parse_object(%);\n", substring(json, i));
        i = eat_white_spaces(json, i);
        if i >= json.count {
            return set_error(result, "Unexpected end of object!");
        }

        if json[i] == {
            case #char "\"";
                if expect_comma return set_error(result, "Expected , or } but got \"");
                expect_comma = true;
                trailing_comma = false;

                // Parse key
                key_end, key := json_parse_string(json, i + 1);
                if key_end < 0 return set_error(result, key);
    
                // Parse colon
                colon_index := eat_white_spaces(json, key_end);
                if colon_index >= json.count return set_error(result, "Expected : but end was reached");
                if json[colon_index] != #char ":" return set_error(result, "Expected : but got another character");

                // Parse value
                value := New(JsonNode);
                value_end := json_parse_value(json, colon_index + 1, value);
                if value_end < 0 {
                    free(value);
                    return value_end; // Failed to parse value!
                }

                item : JsonObjectBody = .{
                    key = key,
                    value = value,
                };
                array_add(*result.obj, item);

                i = value_end;
            case #char ",";
                if !expect_comma return set_error(result, "Expected \" or } but got ,");
                expect_comma = false;
                trailing_comma = true;
                i += 1;
            case #char "}";
                if trailing_comma return set_error(result, "Trailing comma in object!");
                return i + 1;
            case;
                return set_error(result, "Unexpected character in object!");
        }
    }
    return set_error(result);
}

json_parse_array :: (json: string, start_index: int, result: *JsonNode) -> end_index: int {
    // @LEAK This leaks any assigned array items if it fails after assigning them!
    #if JSON_DEBUG print("json_parse_array(%);\n", substring(json, start_index));
    result.kind = .ARRAY;
    i := start_index;
    expect_comma := false;
    trailing_comma := false;
    while true {
        #if JSON_DEBUG print("LOOP json_parse_array(%);\n", substring(json, i));
        i = eat_white_spaces(json, i);
        if i >= json.count {
            return set_error(result, "Unexpected end of array!");
        }

        if json[i] == {
            case;
                if expect_comma return set_error(result, "Expected , or ] but got some other character");
                trailing_comma = false;

                // Parse value
                value : JsonNode;
                value_end := json_parse_value(json, i, *value);
                if value_end < 0 {
                    return value_end; // Failed to parse value!
                }

                array_add(*result.arr, value);

                i = value_end;
                expect_comma = true;
            case #char ",";
                if !expect_comma return set_error(result, "Expected \" or ] but got ,");
                expect_comma = false;
                trailing_comma = true;
                i += 1;
            case #char "]";
                if trailing_comma return set_error(result, "Trailing comma in array!");
                return i + 1;
        }
    }
    return set_error(result);
}

set_error :: (node: *JsonNode, err: string = "") -> int {
    #if JSON_DEBUG print("set_error(%, %);\n", <<node, err);
    node.kind = .ERROR;
    node.err = err;
    return -1;
}

json_free :: (node: JsonNode) {
    if node.kind == {
        case .OBJECT;
            for node.obj json_free(*it.value);
            array_free(node.obj);
        case .ARRAY;
            for node.arr json_free(it);
            array_free(node.arr);
    }
}

json_build_to_string :: (builder: *String_Builder, node: JsonNode) -> did_error: bool {
    #if JSON_DEBUG {
        print("json_build_to_string(%)\n", node);
        if node.kind == .ERROR {
            print("Error! %\n", node.err);
        }
    }
    if node.kind == {
        case;
            return true;
        case .NULL;
            append(builder, "null");
        case .BOOL;
            append(builder, ifx node.bol then "true" else "false");
        case .NUMBER_INT;
            append(builder, tprint("%", node.num_int));
        case .NUMBER_FLOAT;
            append(builder, tprint("%", node.num_float));
        case .STRING;
            append(builder, "\"");
            append(builder, node.str);
            append(builder, "\"");
        case .OBJECT;
            append(builder, "{");
            for node.obj {
                append(builder, "\"");
                append(builder, it.key);
                append(builder, "\":");
                json_build_to_string(builder, it.value);
                if it_index != node.obj.count-1 append(builder, ",");
            }
            append(builder, "}");
        case .ARRAY;
            append(builder, "[");
            for node.arr {
                json_build_to_string(builder, it);
                if it_index != node.arr.count-1 append(builder, ",");
            }
            append(builder, "]");
    }
    return false;
}

eat_white_spaces :: inline (json: string, start_index: int) -> int {
    for start_index..json.count-1 {
        if !is_white_space(json[it]) return it;
    }
    return json.count;
}

is_white_space :: inline (char: u8) -> bool {
    return (
        char == #char " "  ||
        char == #char "\n" ||
        char == #char "\r" ||
        char == #char "\t"
    );
}

is_hex :: inline (char: u8) -> bool {
    return (
        (char >= #char "0" && char <= #char "9") ||
        (char >= #char "A" && char <= #char "F") ||
        (char >= #char "a" && char <= #char "f")
    );
}

substring :: (str: string, start: int, end: int = -1) -> string {
    if end == -1 end = str.count;
    assert(start >= 0 && start <= str.count);
    result : string;
    result.data = str.data + start;
    result.count = str.count - start;
    return result;
}

#scope_file

#import "Basic";
