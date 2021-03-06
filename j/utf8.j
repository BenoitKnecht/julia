## from src/boot.j:
# type UTF8String <: String; data::Array{Uint8,1}; end

## basic UTF-8 decoding & iteration ##

const _jl_utf8_offset = [
    uint32(0),
    uint32(12416),
    uint32(925824),
    uint32(63447168),
    uint32(4194836608),
    uint32(2181570688),
]

const _jl_utf8_trailing = [
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5,
]

is_utf8_start(byte::Uint8) = ((byte&192)!=128)

## required core functionality ##

length(s::UTF8String) = length(s.data)

function next(s::UTF8String, i::Index)
    if !is_utf8_start(s.data[i])
        error("invalid UTF-8 character index")
    end
    trailing = _jl_utf8_trailing[s.data[i]+1]
    if length(s.data) < i + trailing
        error("premature end of UTF-8 data")
    end
    c = uint32(0)
    for j = 1:trailing
        c += s.data[i]
        c <<= 6
        i += one(i)
    end
    c += s.data[i]
    i += one(i)
    c -= _jl_utf8_offset[trailing+1]
    char(c), i
end

## overload methods for efficiency ##

function ref(s::UTF8String, r::Range1{Index})
    i = isvalid(s,r.start) ? r.start : nextind(s,r.start)
    j = nextind(s,r.stop) - 1
    UTF8String(s.data[i:j])
end

strchr(s::UTF8String, c::Char) =
    c < 0x80 ? memchr(s.data, c) : invoke(strchr, (String,Char), s, c)
strcat(a::ByteString, b::ByteString, c::ByteString...) = UTF8String(memcat(a,b,c...))
    # ^^ at least one must be UTF-8 or the ASCII-only method would get called

## outputing UTF-8 strings ##

print(s::UTF8String) = print(s.data)
write(io, s::UTF8String) = write(io, s.data)

## transcoding to UTF-8 ##

# NOTE: returns ASCIIString OR UTF8String object:
utf8(s::ByteString) = s
utf8(a::Array{Uint8,1}) = check_utf8(UTF8String(a))
utf8(s::String) = cstring(s)
