// Run this file to build the example program.

build :: () {
    w := compiler_create_workspace("Example Program");
    if !w {
        print("Workspace creation failed.\n");
        return;
    }

    target_options := get_build_options(w);

    if !target_options.output_path {
      target_options.output_path = #filepath;
    }

    if !target_options.output_executable_name {
      target_options.output_executable_name = "example";
    }

    import_path: [..] string;
    array_add(*import_path, #filepath);
    for target_options.import_path {
        array_add(*import_path, it);
    }
    target_options.import_path = import_path;

    set_build_options(target_options, w);

    compiler_begin_intercept(w);

    // Now let's add the code.
    add_build_file("example.jai", w);

    success := true;
    while true {
        message := compiler_wait_for_message();
        assert(message.workspace == w);

        if message.kind == .COMPLETE {
            complete := cast(*Message_Complete) message;
            if complete.error_code != .NONE {
                success = false;
            }
            break;
        }
    }

    compiler_end_intercept(w);

    if !success return;

    set_build_options_dc(.{do_output=false});
}

#run build();

#import "Basic";
#import "Compiler";
