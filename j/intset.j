type IntSet
    bits::Array{Uint32,1}
    limit::Size

    IntSet() = IntSet(1024)
    IntSet(max::Int) = (lim = (max+31) & -32;
                        new(zeros(Uint32,lim>>>5), lim))
end
intset(args...) = add_each(IntSet(), args)

function add(s::IntSet, n::Int)
    if n >= s.limit
        lim = long(n + div(n,2))
        olsz = length(s.bits)
        newbits = Array(Uint32,(lim+31)>>>5)
        newbits[1:olsz] = s.bits
        for i=(olsz+1):length(newbits); newbits[i] = 0; end
        s.bits = newbits
        s.limit = lim
    end
    s.bits[n>>5 + 1] |= (1<<(n&31))
    return s
end

function add_each(s::IntSet, ns)
    for n = ns
        add(s, n)
    end
    return s
end

function del(s::IntSet, n::Int)
    if n < s.limit
        s.bits[n>>5 + 1] &= ~(1<<(n&31))
    end
    return s
end

function del_each(s::IntSet, ns)
    for n = ns
        del(s, n)
    end
    return s
end

function del_all(s::IntSet)
    s.bits[:] = 0
    return s
end

function has(s::IntSet, n::Int)
    if n >= s.limit
        false
    else
        (s.bits[n>>5 + 1] & (1<<(n&31))) != 0
    end
end

start(s::IntSet) = int64(0)
done(s::IntSet, i) = (next(s,i)[1] >= s.limit)
function next(s::IntSet, i)
    n = ccall(:bitvector_next, Int64, (Ptr{Uint32}, Uint64, Uint64),
              s.bits, uint64(i), uint64(s.limit))
    (n, n+1)
end

isempty(s::IntSet) =
    ccall(:bitvector_any1, Uint32, (Ptr{Uint32}, Uint64, Uint64),
          s.bits, uint64(0), uint64(s.limit))==0

function choose(s::IntSet)
    n = next(s,0)[1]
    if n >= s.limit
        error("choose: set is empty")
    end
    return n
end

length(s::IntSet) = numel(s)
numel(s::IntSet) =
    int32(ccall(:bitvector_count, Uint64, (Ptr{Uint32}, Uint64, Uint64),
                s.bits, uint64(0), uint64(s.limit)))

function show(s::IntSet)
    print("intset(")
    first = true
    for n = s
        if !first
            print(", ")
        end
        print(n)
        first = false
    end
    print(")")
end
