## system word size ##

const WORD_SIZE = long(Size.nbits)

## converting pointers to an appropriate uint ##

if WORD_SIZE == 64
    typealias PtrInt Uint64
else
    typealias PtrInt Uint32
end

const C_NULL = box(Ptr{Void}, unbox(Long,0))

# pointer to int
convert(::Type{PtrInt}, x::Ptr) = box(PtrInt,unbox(PtrInt,x))
convert{T<:Int}(::Type{T}, x::Ptr) = convert(T,uint(x))

# int to pointer
convert{T}(::Type{Ptr{T}}, x::Int) = box(Ptr{T},unbox(PtrInt,ptrint(x)))

# pointer to pointer
convert{T}(::Type{Ptr{T}}, p::Ptr{T}) = p
convert{T}(::Type{Ptr{T}}, p::Ptr) = box(Ptr{T},unbox(PtrInt,p))

# object to pointer
convert(::Type{Ptr{Uint8}}, x::Symbol) =
    ccall(:jl_symbol_name, Ptr{Uint8}, (Any,), x)
convert(::Type{Ptr{Void}}, a::Array) =
    ccall(:jl_array_ptr, Ptr{Void}, (Any,), a)
convert(::Type{Ptr{Void}}, a::Array{None}) =
    ccall(:jl_array_ptr, Ptr{Void}, (Any,), a)
convert{T}(::Type{Ptr{T}}, a::Array{T}) =
    convert(Ptr{T}, convert(Ptr{Void}, a))

pointer{T}(::Type{T}, x::PtrInt) = convert(Ptr{T}, x)
# note: these definitions don't mean any AbstractArray is convertible to
# pointer. they just map the array element type to the pointer type for
# convenience in cases that work.
pointer{T}(x::AbstractArray{T}) = convert(Ptr{T},x)
pointer{T}(x::AbstractArray{T}, i::Index) = convert(Ptr{T},x) + (i-1)*sizeof(T)

uint(x::Ptr) = convert(PtrInt, x)
ptrint(x) = convert(PtrInt, x)

@eval sizeof(::Type{Ptr}) = $div(WORD_SIZE,8)

## limited pointer arithmetic & comparison ##

isequal(x::Ptr, y::Ptr) = uint(x) == uint(y)
-(x::Ptr, y::Ptr) = uint(x) - uint(y)

+{T}(x::Ptr{T}, y::Int) = pointer(T, uint(x) + ptrint(y))
-{T}(x::Ptr{T}, y::Int) = pointer(T, uint(x) - ptrint(y))

+(x::Int, y::Ptr) = y + x
