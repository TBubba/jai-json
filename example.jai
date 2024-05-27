json := #string END
{
  "lorem": "ipsum",
  "whats": ["up", "dude", "?"],
  "integer": 123,
  "fraction": 123.456,
  "exponent": 123.456e7,
  "a": { "b": { "c": { "d": [3] } } }
}
END;

main :: () {
    print("Input: %\n", json);

    parsed : Json.JsonNode;
    end_index := Json.json_parse(json, *parsed);
    defer Json.json_free(parsed);

    print("Parsed: % %\n", end_index, parsed);

    builder : String_Builder;
    init_string_builder(*builder);
    defer reset(*builder);
    Json.json_build_to_string(*builder, parsed);
    out_json := builder_to_string(*builder);

    print("Output: %\n", out_json);
}

#import "Basic";
Json :: #import "Json";
