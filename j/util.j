# shell

ls() = system("ls")

catfile(file::String) = system(strcat("cat ", file))

# timing

clock() = ccall(:clock_now, Float64, ())

function tic()
    t0 = clock()
    tls(:TIMERS, (t0, get(tls(), :TIMERS, ())))
    return t0
end

function toc(noisy::Bool)
    t1 = clock()
    timers = get(tls(), :TIMERS, ())
    if is(timers,())
        error("toc() without tic()")
    end
    t0 = timers[1]
    tls(:TIMERS, timers[2])
    t = t1-t0
    if noisy
        println("elapsed time: ", t, " seconds")
    end
    t
end

toc() = toc(true)
toq() = toc(false)

# prints elapsed time
# returns expression value
macro time(ex)
  t0, val, t1 = gensym(3)
  quote
    local $t0 = clock()
    local $val = $ex
    local $t1 = clock()
    println("elapsed time: ", $t1-$t0, " seconds")
    $val
  end
end

# prints nothing
# returns elapsed time
macro elapsed(ex)
  t0, val, t1 = gensym(3)
  quote
    local $t0 = clock()
    local $val = $ex
    local $t1 = clock()
    $t1-$t0
  end
end

function peakflops()
    a = rand(2000,2000)
    t = @elapsed a*a
    t = @elapsed a*a
    floprate = (2*2000.0^3/t)
    println("The peak flop rate is ", floprate*1e-9, " gigaflops")
    floprate
end

macro benchmark(n,ex,T)
    s = gensym()
    quote
        local $s
        @time for i=1:long($n)
            x = convert($T,i)
            $s = $ex
        end
        $s
    end
end

# source files, editing

edit(fl::String) = edit(fl, 1)
function edit(fl::String, line::Int)
    editor = get(ENV, "JULIA_EDITOR", "emacs")
    issrc = fl[end-1:end] == ".j"
    if issrc
        if editor == "emacs"
            jmode = "$JULIA_HOME/contrib/julia-mode.el"
            run(`emacs $fl --eval "(progn
                                     (require 'julia-mode \"$jmode\")
                                     (julia-mode)
                                     (goto-line $line))"`)
        elseif editor == "vim"
            run(`vim $fl +$line`)
        elseif editor == "textmate"
            run(`mate -w $fl -l $line`)
        else
            error("Invalid JULIA_EDITOR value: $(show_to_string(editor))")
        end
        load(fl)
    else
        if editor == "emacs"
            run(`emacs $fl --eval "(goto-line $line)"`)
        elseif editor == "vim"
            run(`vim $fl +$line`)
        elseif editor == "textmate"
            run(`mate $fl -l $line`)
        else
            error("Invalid JULIA_EDITOR value: $(show_to_string(editor))")
        end
    end
    nothing
end

function_loc(f::Function) = function_loc(f, (Any...))

function function_loc(f::Function, types)
    for m = getmethods(f, types)
        if isa(m[3],LambdaStaticData)
            ast = m[3].ast
            ln = ast.args[3].args[1]
            if isa(ln,Expr) && is(ln.head,:line)
                return (string(ln.args[2]), ln.args[1])
            end
        end
    end
    error("could not find function definition")
end

edit(f::Function) = edit(function_loc(f)...)
edit(f::Function, t) = edit(function_loc(f,t)...)

function parse_help(stream)
    helpdb = HashTable()
    for l = each_line(stream)
        if isempty(l)
            continue
        end
        if length(l) >= 3 && l[1:3]=="## "
            heading = l[4:end-1]
            category = HashTable()
            helpdb[heading] = category
            continue
        end
        if l[1]=='`'
            parts = split(l, '—')
            sig = parts[1][2:end-2]
            if length(parts) > 1
                desc = parts[2]
            else
                desc = ""
            end
            m = match(r"(\w+!?)\(", sig)
            if m != nothing
                # found something of the form "f("
                funcname = m.captures[1]
            else
                # otherwise use whatever's between the ``
                funcname = sig
            end
            entry = (sig, desc)
            if has(category,funcname)
                push(category[funcname], entry)
            else
                category[funcname] = {entry}
            end
        end
    end
    helpdb
end

_jl_helpdb = nothing

const _jl_help_url = "https://raw.github.com/wiki/JuliaLang/julia/Standard-Library-Reference.md"

function _jl_init_help()
    global _jl_helpdb
    if _jl_helpdb == nothing
        println("Downloading help data...")
        cmd = `curl -s $_jl_help_url`
        stream = fdio(read_from(cmd).fd, true)
        spawn(cmd)
        _jl_helpdb = parse_help(stream)
    end
end

function help()
    _jl_init_help()
    print(
" Welcome to Julia. The full manual is available at

    https://github.com/JuliaLang/julia/wiki/

 To get help on a function, try help(function). To search all help text,
 try apropos(\"string\"). To see available functions, try help(category),
 for one of the following categories:

")
    for (cat, tabl) = _jl_helpdb
        if !isempty(tabl)
            print("  ")
            show(cat); println()
        end
    end
end

function help(cat::String)
    _jl_init_help()
    if !has(_jl_helpdb, cat)
        # if it's not a category, try another named thing
        return help_for(cat)
    end
    println("Help is available for the following items:")
    for (func, _) = _jl_helpdb[cat]
        print(func, " ")
    end
    println()
end

function _jl_print_help_entries(entries)
    first = true
    for desc = entries
        if !first
            println()
        end
        print(desc[1], "\n ", desc[2])
        first = false
    end
end

function help_for(fname::String)
    _jl_init_help()
    n = 0
    for (cat, tabl) = _jl_helpdb
        for (func, entries) = tabl
            if func == fname
                _jl_print_help_entries(entries)
                n+=1
                break
            end
        end
    end
    if n == 0
        println("No help information found.")
    end
end

function apropos(txt::String)
    _jl_init_help()
    n = 0
    r = Regex("\\Q$txt", PCRE_CASELESS)
    first = true
    for (cat, tabl) = _jl_helpdb
        if matches(r, cat)
            println("Category: \"$cat\"")
            first = false
        end
    end
    for (cat, tabl) = _jl_helpdb
        for (func, entries) = tabl
            if matches(r, func) || anyp(e->(matches(r,e[1]) || matches(r,e[2])),
                                        entries)
                if !first
                    println()
                end
                _jl_print_help_entries(entries)
                first = false
                n+=1
            end
        end
    end
    if n == 0
        println("No help information found.")
    end
end

function help(f::Function)
    if is(f,help)
        return help()
    end
    help_for(string(f)[2:end-1])
end

help(t::CompositeKind) = help_for(string(t.name))

function help(x)
    show(x)
    t = typeof(x)
    println(" is of type $t")
    if isa(t,CompositeKind)
        println("  which has fields $(t.names)")
    end
end
