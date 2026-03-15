#+feature dynamic-literals
package first

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"


Command :: struct {
	args:        []string,
	working_dir: string,
	silent:      bool,
}

BIN_SRC :: "first/main.odin"
WORK_DIR :: "."
DEFAULT_BUILD_ARGS := []string{"-vet", "-vet-style", "-warnings-as-errors"}

usage :: proc() {
	fmt.printfln(
		`%s is a thin wrapper over the odin build system inspired by nob.h

Usage: %s

   timings  Show build timings (adds -show-timings to build args)
   release  Build odin with optimizations (-o:speed...)
   help     Prints this help message
        `,
		os.args[0],
		os.args[0],
	)
	os.exit(0)
}


main :: proc() {
	rebuild()
	version := get_version()

	show_timings := false
	release_mode := false
	for arg_index in 1 ..< len(os.args) {
		arg := os.args[arg_index]
		switch arg {
		case "timings":
			show_timings = true
		case "release":
			release_mode = true
		case "help":
			usage()
		case:
			fmt.printfln("Unknown arg <%s>", arg)
			os.exit(3)
		}
	}


	build_args := [dynamic]string{"odin", "build", WORK_DIR, "-out:smp"}
	for default_arg in DEFAULT_BUILD_ARGS {append(&build_args, default_arg)}
	if show_timings {append(&build_args, "-show-timings")}

	if release_mode {
		append(&build_args, fmt.aprintf("-define:VERSION=%s", version), "-o:speed")
	} else {
		append(&build_args, fmt.aprintf("-define:VERSION=%s-debug", version), "-debug")
	}

	build_state, _, build_err := run_command(Command{args = build_args[:]})
	if !build_state.success {fatal(build_err)}
	if build_err != "" {fmt.eprintln(build_err)}

	when ODIN_OS == .Linux {
		if release_mode { setup_desktop_file() }
	}

}

setup_desktop_file :: proc() {
	desktop_file := `
[Desktop Entry]
Name=SMP (Simple Music Player)
Exec=smp
Icon=<replace>
Type=Application
Categories=Music;
`
	smp_root, err := os.get_executable_directory(context.allocator)
	if err != nil { fmt.eprintln("Failed to get smp root path") }

	logo_path         := fmt.tprintf("%s/resources/logo/smp.png", smp_root)
	desktop_file_path := fmt.tprintf("./resources/smp.desktop")

	d, _ := strings.replace(desktop_file, "<replace>", logo_path, 1)
	if os.is_file(desktop_file_path) { return }
	f, f_err := os.open(
		desktop_file_path,
		{.Create, .Write},
		{.Read_User, .Write_User, .Read_Group, .Write_Group, .Read_Other, .Write_Other},
	)
	defer os.close(f)
	ensure(f_err == nil)
	os.write(f, transmute([]u8)d)
	fmt.eprintln("[INFO]: Created .desktop file at", desktop_file_path)
}

run_command :: proc(
	cmd: Command,
) -> (
	state: os.Process_State,
	contents: string,
	err_msg: string,
) {
	process_desc: os.Process_Desc = {
		working_dir = cmd.working_dir,
		command     = cmd.args,
	}

	if !cmd.silent {fmt.printfln("[INFO] CMD: %s", strings.join(cmd.args, " "))}
	process_state, stdout, stderr, process_err := os.process_exec(process_desc, context.allocator)
	if process_err != nil {
		return os.Process_State{success = false}, "", os.error_string(process_err)
	}

	defer {
		delete(stdout)
		delete(stderr)
	}
	// fmt.printfln("process_state: %v\nstdout: %s\nstderr: %s", process_state, stdout, stderr)
	return process_state, strings.clone(cast(string)stdout), strings.clone(cast(string)stderr)
}

rebuild :: proc() {
	current_bin := os.args[0]
	if strings.has_suffix(current_bin, ".old") { fatal("Using the .old bin, You probably meant to use first.bin") }

	bin_modified_time, bin_mtime_err := os.last_write_time_by_name(current_bin)
	if bin_mtime_err != nil {
		fatal(os.error_string(bin_mtime_err))
	}
	bin_src_modified_time, bin_src_mtime_err := os.last_write_time_by_name(BIN_SRC)
	if bin_src_mtime_err != nil {
		fatal(os.error_string(bin_src_mtime_err))
	}

	diff := time.diff(bin_modified_time, bin_src_modified_time)
	if diff < 0 { return }

	old_bin := fmt.aprintf("%s.old", current_bin)
	rename_err := os.rename(current_bin, old_bin)
	if rename_err != nil {fatal("Failed to rename binary")}
	fmt.printfln("[INFO] renamed %s -> %s", current_bin, old_bin)

	rebuild_state, rebuild_out, rebuild_err := run_command(
		Command {
			args = []string{"odin", "build", "first", fmt.aprintf("-out:%s", current_bin)},
			working_dir = WORK_DIR,
		},
	)
	if !rebuild_state.success {
		_ = os.rename(old_bin, current_bin)
		fmt.eprintln("[ERROR] rebuild failed reverting ", old_bin, " -> ", current_bin)
		fatal(rebuild_err)
	}

	// run ourself again as a subprocess
	rerun_cmds := [dynamic]string{current_bin}
	for old_arg in os.args[1:] {append(&rerun_cmds, old_arg)}
	rerun_state, rerun_out, rerun_err := run_command(
		Command{args = rerun_cmds[:], working_dir = WORK_DIR},
	)

	if rerun_out != "" { fmt.print(rerun_out) }
	if rerun_err != "" { fmt.eprint(rerun_err) }
	os.exit(rerun_state.exit_code)
}

get_version :: proc() -> string {
	DEFAULT_TAG :: "v0.0.0-1"

	commit_state, commit_out, c_err_msg := run_command(
		Command {
			args = []string{"git", "rev-parse", "--short=10", "HEAD"},
			working_dir = WORK_DIR,
			silent = true,
		},
	)
	if !commit_state.success { fatal(c_err_msg) }
	commit_hash := strings.trim_right(commit_out, "\n")

	tag_state, tag_out, t_err_msg := run_command(
		Command {
			args = []string{"git", "describe", "--tags", "--abbrev=0"},
			working_dir = WORK_DIR,
			silent = true,
		},
	)
	tag := strings.trim_right(tag_out, "\n")
	if !tag_state.success {fmt.eprintln("[WARN] No tags found, using default tag"); tag = DEFAULT_TAG}

	return fmt.aprintf("%s-%s", tag, commit_hash)
}

fatal :: proc(message: string) {
	fmt.eprintln(message)
	os.exit(1)
}

