## core libc calls ##

hasenv(var::String) =
    ccall(dlsym(libc, :getenv),
          Ptr{Uint8}, (Ptr{Uint8},), cstring(var)) != C_NULL

function getenv(var::String)
    val = ccall(dlsym(libc, :getenv),
                Ptr{Uint8}, (Ptr{Uint8},), cstring(var))
    if val == C_NULL
        error("getenv: undefined variable: ", var)
    end
    cstring(val)
end

function setenv(var::String, val::String, overwrite::Bool)
    ret = ccall(dlsym(libc, :setenv), Int32,
                (Ptr{Uint8}, Ptr{Uint8}, Int32),
                cstring(var), cstring(val), int32(overwrite))
    system_error(:setenv, ret != 0)
end

setenv(var::String, val::String) = setenv(var, val, true)

function unsetenv(var::String)
    ret = ccall(dlsym(libc, :unsetenv), Int32, (Ptr{Uint8},), var)
    system_error(:unsetenv, ret != 0)
end

## ENV: hash interface ##

type EnvHash <: Associative; end

const ENV = EnvHash()

function ref(::EnvHash, k::String)
    val = ccall(dlsym(libc, :getenv), Ptr{Uint8}, (Ptr{Uint8},), cstring(k))
    if val == C_NULL
        throw(KeyError(k))
    end
    cstring(val)
end

function get(::EnvHash, k::String, deflt)
    val = ccall(dlsym(libc, :getenv), Ptr{Uint8}, (Ptr{Uint8},), cstring(k))
    if val == C_NULL
        return deflt
    end
    cstring(val)
end

has(::EnvHash, k::String) = hasenv(k)
del(::EnvHash, k::String) = unsetenv(k)
assign(::EnvHash, v::String, k::String) = (setenv(k,v); v)

start(::EnvHash) = int32(0)
done(::EnvHash, i) = (ccall(:jl_environ, Any, (Int32,), int32(i)) == nothing)
function next(::EnvHash, i)
    i = int32(i)
    env = ccall(:jl_environ, Any, (Int32,), i)
    if env == nothing
        error("environ: index out of range")
    end
    env::ByteString
    m = match(r"^(.*?)=(.*)$", env)
    if m == nothing
        error("malformed environment entry: $env")
    end
    (m.captures, i+one(i))
end

function show(::EnvHash)
    for (k,v) = ENV
        println("$k=$v")
    end
end

## misc environment-related functionality ##

tty_cols() = parse_int(Int32, get(ENV,"COLUMNS","80"), 10)
tty_rows() = parse_int(Int32, get(ENV,"LINES","25"), 10)
