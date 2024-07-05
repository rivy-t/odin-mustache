BUILD_DIR := build
BIN_DIR := ${BUILD_DIR}/bin

####

MAKE_VERSION_major := $(word 1,$(subst ., ,${MAKE_VERSION}))
MAKE_VERSION_minor := $(word 2,$(subst ., ,${MAKE_VERSION}))

# require at least `make` v4.0 (minimum needed for correct path functions)
MAKE_VERSION_fail := $(filter ${MAKE_VERSION_major},3 2 1 0)
ifeq (${MAKE_VERSION_major},4)
MAKE_VERSION_fail := $(filter ${MAKE_VERSION_minor},)
endif
ifneq (${MAKE_VERSION_fail},)
# $(call %error,`make` v4.0+ required (currently using v${MAKE_VERSION}))
$(error ERR!: `make` v4.0+ required (currently using v${MAKE_VERSION}))
endif

makefile_path := $(lastword ${MAKEFILE_LIST})## note: *must* precede any makefile imports (ie, `include ...`)

makefile_abs_path := $(abspath ${makefile_path})
makefile_dir := $(abspath $(dir ${makefile_abs_path}))
make_invoke_alias ?= $(if $(filter-out Makefile,${makefile_path}),${MAKE} -f "${makefile_path}",${MAKE})
current_dir := ${CURDIR}
makefile_set := $(wildcard ${makefile_path} ${makefile_path}.config ${makefile_path}.target)
makefile_set_abs := $(abspath ${makefile_set})

#### * determine OS ID

# note: environment/${OS}=="Windows_NT" for XP, 2000, Vista, 7, 10, 11, ...
OSID := $(or $(and $(filter .exe,$(patsubst %.exe,.exe,$(subst $() $(),_,${SHELL}))),$(filter win,${OS:Windows_NT=win})),nix)## OSID == [nix,win]
ifeq (${OSID},win)
# WinOS-specific settings
# * set SHELL (from COMSPEC or SystemRoot, if possible)
# ... `make` may otherwise use an incorrect shell (eg, `sh` or `bash`, if found in PATH); "syntax error: unexpected end of file" or "CreateProcess(NULL,...)" error output is indicative
SHELL := cmd$()## start with a known default shell (`cmd` for WinOS XP+)
# * set internal variables from environment variables (if available)
# ... avoid env var case variance issues and use fallbacks
# ... note: assumes *no spaces* within the path values specified by ${ComSpec}, ${SystemRoot}, or ${windir}
HOME := $(or $(strip $(shell echo %HOME%)),$(strip $(shell echo %UserProfile%)))
COMSPEC := $(strip $(shell echo %ComSpec%))
SystemRoot := $(or $(strip $(shell echo %SystemRoot%)),$(strip $(shell echo %windir%)))
SHELL := $(firstword $(wildcard ${COMSPEC} ${SystemRoot}/System32/cmd.exe) cmd)
endif

#### * determine BASEPATH

# use ${BASEPATH} as an anchor to allow otherwise relative path specification of files
ifneq (${makefile_dir},${current_dir})
BASEPATH := ${makefile_dir:${current_dir}/%=%}
# BASEPATH := $(patsubst ./%,%,${makefile_dir:${current_dir}/%=%}/)
endif
ifeq (${BASEPATH},)
BASEPATH := .
endif

#### * constants and methods

falsey_list := false 0 f n never no none off
falsey := $(firstword ${falsey_list})
false := $()
true := true
truthy := ${true}

devnull := $(if $(filter win,${OSID}),NUL,/dev/null)
int_max := 2147483647## largest signed 32-bit integer; used as arbitrary max expected list length

NULL := $()
BACKSLASH := $()\$()
COMMA := ,
DOLLAR := $$
DOT := .
ESC := $()$()## literal ANSI escape character (required for ANSI color display output; also used for some string matching)
HASH := \#
PAREN_OPEN := $()($()
PAREN_CLOSE := $())$()
SLASH := /
SPACE := $() $()

[lower] := a b c d e f g h i j k l m n o p q r s t u v w x y z
[upper] := A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
[alpha] := ${[lower]} ${[upper]}
[digit] := 1 2 3 4 5 6 7 8 9 0
[punct] := ~ ` ! @ ${HASH} ${DOLLAR} % ^ & * ${PAREN_OPEN} ${PAREN_CLOSE} _ - + = { } [ ] | ${BACKSLASH} : ; " ' < > ${COMMA} ? ${SLASH} ${DOT}

%not = $(if ${1},${false},$(or ${1},${true}))
%eq = $(or $(and $(findstring ${1},${2}),$(findstring ${2},${1})),$(if ${1}${2},${false},${true}))# note: `call %eq,$(),$()` => ${true}
%neq = $(if $(call %eq,${1},${2}),${false},$(or ${1},${2},${true}))# note: ${1} != ${2} => ${false}; ${1} == ${2} => first non-empty value (or ${true})

# %falsey := $(firstword ${falsey})
# %truthy := $(firstword ${truthy})

%as_truthy = $(if $(call %is_truthy,${1}),${truthy},${falsey})# note: returns 'truthy'-type text value (eg, true => 'true' and false => 'false')
%is_truthy = $(if $(filter-out ${falsey_list},$(call %lc,${1})),${1},${false})# note: returns `make`-type boolean value (eg, true => non-empty and false => $()/empty/null)
%is_falsey = $(call %not,$(call %is_truthy,${1}))# note: returns `make`-type boolean value (eg, true => non-empty and false => $()/empty/null)

%range = $(if $(word ${1},${2}),$(wordlist 1,${1},${2}),$(call %range,${1},${2} $(words _ ${2})))
%repeat = $(if $(word ${2},${1}),$(wordlist 1,${2},${1}),$(call %repeat,${1} ${1},${2}))

%head = $(firstword ${1})
%tail = $(wordlist 2,${int_max},${1})
%chop = $(wordlist 2,$(words ${1}),_ ${1})
%append = ${2} ${1}
%prepend = ${1} ${2}
%length = $(words ${1})

%_position_ = $(if $(findstring ${1},${2}),$(call %_position_,${1},$(wordlist 2,$(words ${2}),${2}),_ ${3}),${3})
%position = $(words $(call %_position_,${1},${2}))

%map = $(foreach elem,${2},$(call ${1},${elem}))# %map(fn,list) == [ fn(list[N]),... ]
%filter_by = $(strip $(foreach elem,${3},$(and $(filter $(call ${1},${2}),$(call ${1},${elem})),${elem})))# %filter_by(fn,item,list) == [ list[N] iff fn(item)==fn(list[N]), ... ]
%uniq = $(if ${1},$(firstword ${1}) $(call %uniq,$(filter-out $(firstword ${1}),${1})))

%none = $(if $(call %map,${1},${2}),${false},${true})## %none(fn,list) => all of fn(list_N) == ""
%some = $(if $(call %map,${1},${2}),${true},${false})## %some(fn,list) => any of fn(list_N) != ""
%any = %some## %any(), aka %some(); %any(fn,list) => any of fn(list_N) != ""
%all = $(if $(call %map,%not,$(call %map,${1},${2})),${false},${true})## %all(fn,list) => all of fn(list_N) != ""

%cross = $(foreach a,${2},$(foreach b,${3},$(call ${1},${a},${b})))# %cross(fn,listA,listB) == [ fn(listA[N],listB[M]), ... {for all combinations of listA and listB }]
%join = $(subst ${SPACE},${1},$(strip ${2}))# %join(text,list) == join all list elements with text
%replace = $(foreach elem,${3},$(foreach pat,${1},${elem:${pat}=${2}}))# %replace(pattern(s),replacement,list) == [ ${list[N]:pattern[M]=replacement}, ... ]

%tr = $(strip $(if ${1},$(call %tr,$(wordlist 2,$(words ${1}),${1}),$(wordlist 2,$(words ${2}),${2}),$(subst $(firstword ${1}),$(firstword ${2}),${3})),${3}))
%lc = $(call %tr,${[upper]},${[lower]},${1})
%uc = $(call %tr,${[lower]},${[upper]},${1})

%as_nix_path = $(subst \,/,${1})
%as_win_path = $(subst /,\,${1})
%as_os_path = $(call %as_${OSID}_path,${1})

%strip_leading_cwd = $(patsubst ./%,%,${1})# %strip_leading_cwd(list) == normalize paths; stripping any leading './'
%strip_leading_dotslash = $(patsubst ./%,%,${1})# %strip_leading_dotslash(list) == normalize paths; stripping any leading './'

%dirs_in = $(dir $(wildcard ${1:=/*/.}))
%filename = $(notdir ${1})
%filename_base = $(basename $(notdir ${1}))
%filename_ext = $(suffix ${1})
%filename_stem = $(firstword $(subst ., ,$(basename $(notdir ${1}))))
%recursive_wildcard = $(strip $(foreach entry,$(wildcard ${1:=/*}),$(strip $(call %recursive_wildcard,${entry},${2}) $(filter $(subst *,%,${2}),${entry}))))

%filter_by_stem = $(call %filter_by,%filename_stem,${1},${2})

# * `%is_gui()` tests filenames for a match to '*[-.]gui{${EXEEXT},.${O}}'
%is_gui = $(if $(or $(call %is_gui_exe,${1}),$(call %is_gui_obj,${1})),${1},${false})
%is_gui_exe = $(if $(and $(patsubst %-gui${EXEEXT},,${1}),$(patsubst %.gui${EXEEXT},,${1})),${false},${1})
%is_gui_obj = $(if $(and $(patsubst %-gui.${O},,${1}),$(patsubst %.gui.${O},,${1})),${false},${1})

# %any_gui = $(if $(foreach file,${1},$(call %is_gui,${file})),${true},${false})
# %all_gui = $(if $(foreach file,${1},$(call %not,$(call %is_gui,${file}))),${false},${true})
# %any_gui = $(call %any,%is_gui,${1})
# %all_gui = $(call %all,%is_gui,${1})

ifeq (${OSID},win)
%mkdir_shell_s = (if NOT EXIST $(call %shell_escape,$(call %as_win_path,${1})) ${MKDIR} $(call %shell_escape,$(call %as_win_path,${1})) >${devnull} 2>&1 && ${ECHO} ${true})
else
%mkdir_shell_s = (${MKDIR} $(call %shell_escape,${1}) >${devnull} 2>&1 && ${ECHO} ${true})
endif
%mkdir = $(shell $(call %mkdir_shell_s,${1}))

# * `rm` shell commands; note: return `${true}` result when argument (`${1}`) is successfully removed (to support verbose feedback display)
ifeq (${OSID},win)
%rm_dir_shell_s = (if EXIST $(call %shell_quote,$(call %as_win_path,${1})) (${RMDIR} $(call %shell_quote,$(call %as_win_path,${1})) >${devnull} 2>&1 && ${ECHO} ${true}))
%rm_file_shell_s = (if EXIST $(call %shell_quote,$(call %as_win_path,${1})) (${RM} $(call %shell_quote,$(call %as_win_path,${1})) >${devnull} 2>&1 && ${ECHO} ${true}))
%rm_file_globset_shell_s = (for %%G in $(call %shell_quote,($(call %as_win_path,${1}))) do (${RM} "%%G" >${devnull} 2>&1 && ${ECHO} ${true}))
else
%rm_dir_shell_s = (ls -d $(call %shell_escape,${1}) >${devnull} 2>&1 && { ${RMDIR} $(call %shell_escape,${1}) >${devnull} 2>&1 && ${ECHO} ${true}; } || true)
%rm_file_shell_s = (ls -d $(call %shell_escape,${1}) >${devnull} 2>&1 && { ${RM} $(call %shell_escape,${1}) >${devnull} 2>&1 && ${ECHO} ${true}; } || true)
%rm_file_globset_shell_s = (for file in $(call %shell_escape,${1}); do ls -d "$${file}" >${devnull} 2>&1 && ${RM} "$${file}"; done && ${ECHO} "${true}"; done)
endif

# NOTE: `_ := $(call %rm_dir,...)` or `$(if $(call %rm_dir,...))` can be used to avoid interpreting in-line output as a makefile command/rule (avoids `*** missing separator` errors)
%rm_dir = $(shell $(call %rm_dir_shell_s,${1}))
%rm_file = $(shell $(call %rm_file_shell_s,${1}))
%rm_file_globset = $(shell $(call %rm_file_globset_shell_s,${1}))
%rm_dirs = $(strip $(call %map,%rm_dir,${1}))
%rm_dirs_verbose = $(strip $(call %map,$(eval %f=$$(if $$(call %rm_dir,$${1}),$$(call %info,'$${1}' removed.),))%f,${1}))
%rm_files = $(strip $(call %map,%rm_file,${1}))
%rm_files_verbose = $(strip $(call %map,$(eval %f=$$(if $$(call %rm_file,$${1}),$$(call %info,'$${1}' removed.),))%f,${1}))
%rm_file_globsets = $(strip $(call %map,%rm_file_globset,${1}))
%rm_file_globsets_verbose = $(strip $(call %map,$(eval %f=$$(if $$(call %rm_file_globset,$${1}),$$(call %info,'$${1}' removed.),))%f,${1}))

# %rm_dirs_verbose_cli = $(call !shell_noop,$(call %rm_dirs_verbose,${1}))

ifeq (${OSID},win)
%shell_escape = $(call %tr,^ | < > %,^^ ^| ^< ^> ^%,${1})
else
%shell_escape = '$(call %tr,','"'"',${1})'
endif

ifeq (${OSID},win)
%shell_quote = "$(call %shell_escape,${1})"
else
%shell_quote = $(call %shell_escape,${1})
endif

# ref: <https://superuser.com/questions/10426/windows-equivalent-of-the-linux-command-touch/764716> @@ <https://archive.is/ZjFSm>
ifeq (${OSID},win)
%touch_shell_s = type NUL >> $(call %shell_quote,$(call %as_win_path,${1})) & copy >NUL /B $(call %shell_quote,$(call %as_win_path,${1})) +,, $(call %shell_quote,$(call %as_win_path,${1}))
else
%touch_shell_s = touch $(call %shell_quote,${1})
endif
%touch = $(shell $(call %touch_shell_s,${1}))

@mkdir_rule = ${1} : ${2} ; @${MKDIR} $(call %shell_quote,$$@) >${devnull} 2>&1 && ${ECHO} $(call %shell_escape,$(call %info_text,created '$$@'.))

!shell_noop = ${ECHO} >${devnull}

####

## determine COLOR based on NO_COLOR and CLICOLOR_FORCE/CLICOLOR; refs: <https://bixense.com/clicolors>@@<https://archive.is/mF4IA> , <https://no-color.org>@@<https://archive.ph/c32Wn>
COLOR := $(if $(call %is_truthy,${NO_COLOR}),false,${COLOR})## unconditionally NO_COLOR => COLOR=false
COLOR := $(if $(filter auto,${COLOR}),$(if $(call %is_truthy,${CLICOLOR_FORCE}),true,${COLOR}),${COLOR})## if autoset default ('auto') && CLICOLOR_FORCE => COLOR=true
COLOR := $(if $(filter auto,${COLOR}),$(if $(and ${CLICOLOR},$(call %is_falsey,${CLICOLOR})),false,${COLOR}),${COLOR})## if autoset default ('auto') && defined CLICOLOR && !CLICOLOR => COLOR=false

####

override COLOR := $(call %as_truthy,$(or $(filter-out auto,$(call %lc,${COLOR})),${MAKE_TERMOUT}))
override DEBUG := $(call %as_truthy,${DEBUG})
override STATIC := $(call %as_truthy,${STATIC})
override VERBOSE := $(call %as_truthy,${VERBOSE})

override MAKEFLAGS_debug := $(call %as_truthy,$(or $(call %is_truthy,${MAKEFLAGS_debug}),$(call %is_truthy,${MAKEFILE_debug})))

####

color_black := $(if $(call %is_truthy,${COLOR}),${ESC}[0;30m,)
color_blue := $(if $(call %is_truthy,${COLOR}),${ESC}[0;34m,)
color_cyan := $(if $(call %is_truthy,${COLOR}),${ESC}[0;36m,)
color_green := $(if $(call %is_truthy,${COLOR}),${ESC}[0;32m,)
color_magenta := $(if $(call %is_truthy,${COLOR}),${ESC}[0;35m,)
color_red := $(if $(call %is_truthy,${COLOR}),${ESC}[0;31m,)
color_yellow := $(if $(call %is_truthy,${COLOR}),${ESC}[0;33m,)
color_white := $(if $(call %is_truthy,${COLOR}),${ESC}[0;37m,)
color_bold := $(if $(call %is_truthy,${COLOR}),${ESC}[1m,)
color_dim := $(if $(call %is_truthy,${COLOR}),${ESC}[2m,)
color_hide := $(if $(call %is_truthy,${COLOR}),${ESC}[8;30m,)
color_reset := $(if $(call %is_truthy,${COLOR}),${ESC}[0m,)
#
color_command := ${color_dim}
color_path := $()
color_target := ${color_green}
color_success := ${color_green}
color_failure := ${color_red}
color_debug := ${color_cyan}
color_info := ${color_blue}
color_warning := ${color_yellow}
color_error := ${color_red}

%error_text = ${color_error}ERR!:${color_reset} ${1}
%debug_text = ${color_debug}debug:${color_reset} ${1}
%info_text = ${color_info}info:${color_reset} ${1}
%success_text = ${color_success}SUCCESS:${color_reset} ${1}
%failure_text = ${color_failure}FAILURE:${color_reset} ${1}
%warning_text = ${color_warning}WARN:${color_reset} ${1}
%error = $(error $(call %error_text,${1}))
%debug = $(if $(call %is_truthy,${MAKEFLAGS_debug}),$(info $(call %debug_text,${1})),)
%info = $(info $(call %info_text,${1}))
%success = $(info $(call %success_text,${1}))
%failure = $(info $(call %failure_text,${1}))
%warn = $(info $(call %warning_text,${1}))
%warning = $(info $(call %warning_text,${1}))

%debug_var = $(call %debug,${1}="${${1}}")
%info_var = $(call %info,${1}="${${1}}")

#### * OS-specific tools and vars

EXEEXT_nix := $()
EXEEXT_win := .exe

ifeq (${OSID},win)
OSID_name  := windows
OS_PREFIX  := win.
EXEEXT     := ${EXEEXT_win}
#
AWK        := gawk## from `scoop install gawk`; or "goawk" from `go get github.com/benhoyt/goawk`
CAT        := "${SystemRoot}\System32\findstr" /r .*## note: (unlike `type`) will read from STDIN; BUT with multiple file arguments, this will prefix each line with the file name
CP         := copy /y
ECHO       := echo
GREP       := grep## from `scoop install grep`
MKDIR      := mkdir
RM         := del
RM_r       := ${RM} /s
RMDIR      := rmdir /s/q
RMDIR_f    := rmdir /s/q
FIND       := "${SystemRoot}\System32\find"
FINDSTR    := "${SystemRoot}\System32\findstr"
MORE       := "${SystemRoot}\System32\more"
SORT       := "${SystemRoot}\System32\sort"
TYPE       := type## note: will not read from STDIN unless invoked as `${TYPE} CON`
WHICH      := where
#
ECHO_newline := echo.
shell_true := cd .
else
OSID_name  ?= $(shell uname | tr '[:upper:]' '[:lower:]')
OS_PREFIX  := ${OSID_name}.
EXEEXT     := $(if $(call %is_truthy,${CC_is_MinGW_w64}),${EXEEXT_win},${EXEEXT_nix})
#
AWK        := awk
CAT        := cat
CP         := cp
ECHO       := echo
GREP       := grep
MKDIR      := mkdir -p
RM         := rm
RM_r       := ${RM} -r
RMDIR      := ${RM} -r
RMDIR_f    := ${RM} -rf
SORT       := sort
WHICH      := which
#
ECHO_newline := echo
shell_true := true
endif

####

.PHONY: build check debug test

build:
	@$(call %mkdir,${BIN_DIR})
	odin build src -show-timings -out:${BIN_DIR}/odin-mustache${EXEEXT}

check:
	odin check src -vet -strict-style

debug:
	@$(call %mkdir,${BIN_DIR})
	odin build src -show-timings -vet -strict-style -out:${BIN_DIR}/odin-mustache${EXEEXT} -warnings-as-errors -debug

test:
	@$(call %mkdir,${BIN_DIR})
	odin test src -show-timings -vet -strict-style -out:${BIN_DIR}/odin-mustache${EXEEXT} -warnings-as-errors -debug
