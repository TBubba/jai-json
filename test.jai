// Run this file to perform the tests.

#run run_tests();

#no_reset TEST_JSON_VALID : [..]Test;
#run add_test(*TEST_JSON_VALID, "null");
#run add_test(*TEST_JSON_VALID, "true");
#run add_test(*TEST_JSON_VALID, "false");
#run add_test(*TEST_JSON_VALID, "\"\"");
#run add_test(*TEST_JSON_VALID, "\"\\u0123\"");
#run add_test(*TEST_JSON_VALID, "[]");
#run add_test(*TEST_JSON_VALID, "{}");
#run add_test(*TEST_JSON_VALID, "0");
#run add_test(*TEST_JSON_VALID, "0.1");
#run add_test(*TEST_JSON_VALID, "0.1e2");
#run add_test(*TEST_JSON_VALID, "-0");
#run add_test(*TEST_JSON_VALID, "-0.1");
#run add_test(*TEST_JSON_VALID, "-0.1e2");
#run add_test(*TEST_JSON_VALID, "[0.1, 0.2e3, 1.2, 1.2E3, 0]");

#no_reset TEST_JSON_INVALID : [..]Test;
#run add_test(*TEST_JSON_INVALID, "");
#run add_test(*TEST_JSON_INVALID, "\"\\\"");
#run add_test(*TEST_JSON_INVALID, "\"\\z\"");
#run add_test(*TEST_JSON_INVALID, "\"\\u012\"");
#run add_test(*TEST_JSON_INVALID, "[0,]");
#run add_test(*TEST_JSON_INVALID, "[0, [1, [2, [3,]]]]");
#run add_test(*TEST_JSON_INVALID, "{\"foo\": 0,}");
#run add_test(*TEST_JSON_INVALID, "01");
#run add_test(*TEST_JSON_INVALID, "01.1");

Test :: struct {
    json : string;
}

add_test :: (array: *[..]Test, json: string) {
    test : Test;
    test.json = json;
    array_add(array, test);
}

run_tests :: () {
    // Make sure that valid JSON can be parsed
    print("-------------------- Running valid tests --------------------\n");
    for TEST_JSON_VALID {

        parsed : JsonNode;
        end_index := json_parse(it.json, *parsed);
        defer json_free(parsed);
        // print("  Parsed: % %\n", end_index, parsed);

        if end_index < 0 {
            print("X FAILED %! % %\n", it_index, end_index, it.json);
            continue;
        }

        print("SUCCESS %\n", it_index);
    }

    // Make sure that invalid JSON fails to parse
    print("-------------------- Running invalid tests --------------------\n");
    for TEST_JSON_INVALID {

        parsed : JsonNode;
        end_index := json_parse(it.json, *parsed);
        defer json_free(parsed);
        // print("  Parsed: % %\n", end_index, parsed);

        if end_index >= 0 {
            print("X FAILED %! % %\n", it_index, end_index, it.json);
            continue;
        }

        print("SUCCESS %\n", it_index);
    }

    // @TODO Test "json_build_to_string()"

    print("-------------------- TESTS DONE --------------------\n");
}

#import "Basic";
#import "Json";
