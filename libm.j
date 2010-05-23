libm = dlopen("libm")

function vectorize(f)
    eval(`begin
        ($f)(x::Vector) = [ ($f)(x[i]) | i=1:length(x) ]
        ($f)(x::Matrix) = [ ($f)(x[i,j]) | i=1:size(x,1), j=1:size(x,2) ]
    end)
end

for f = {`sin, `cos, `tan, `sinh, `cosh, `tanh, `asin, `acos, `atan, `log,
         `log2, `log10, `log1p, `logb, `exp, `exp2, `expm1, `erf, `erfc,
         `sqrt, `cbrt, `ceil, `floor, `nearbyint, `round, `rint, `trunc}
    eval(`begin
        ($f)(x::Float64) = ccall(dlsym(libm,$string(f)), Float64, (Float64,), x)
        # ($f)(x::Float32) = ccall(dlsym(libm,[$string(f),"f"]), Float32, (Float32,), x)
        ($f)(x::Scalar) = ($f)(convert(Float64,x))
        vectorize($f)
    end)
end

for f = {`isinf, `isnan}
    eval(`begin
        ($f)(x::Float64) = (0 != ccall(dlsym(libm,$string(f)), Int32, (Float64,), x))
        # ($f)(x::Float32) = (0 != ccall(dlsym(libm,[$string(f),"f"]), Int32, (Float32,), x))
        ($f)(x::Int) = false
        vectorize($f)
    end)
end

for f = {`lrint, `lround, `ilogb}
    eval(`begin
        ($f)(x::Float64) = ccall(dlsym(libm,$string(f)), Int32, (Float64,), x)
        # ($f)(x::Float32) = ccall(dlsym(libm,[$string(f),"f"]), Int32, (Float32,), x)
        vectorize($f)
    end)
end

abs(x::Float64) = ccall(dlsym(libm,"fabs"), Float64, (Float64,), x)
abs(x::Float32) = ccall(dlsym(libm,"fabsf"), Float32, (Float32,), x)
vectorize(`abs)

for f = {`atan2, `pow, `remainder, `fmod, `copysign, `hypot, `fmin, `fmax, `fdim}
    eval(`begin
        ($f)(x::Float64, y::Float64) = ccall(dlsym(libm,$string(f)),
                                             Float64,
                                             (Float64, Float64,),
                                             x, y)
        # ($f)(x::Float32, y::Float32) = ccall(dlsym(libm,[$string($f),"f"]),
        #                                      Float32,
        #                                      (Float32, Float32),
        #                                      x, y)
        ($f)(x::Scalar, y::Scalar) = ($f)(convert(Float64,x),convert(Float64,y))
    end)
end

ldexp(x::Float64,e::Int32) = ccall(dlsym(libm,"ldexp"), Float64, (Float64,Int32), x, e)
ldexp(x::Float32,e::Int32) = ccall(dlsym(libm,"ldexpf"), Float32, (Float32,Int32), x, e)

rand() = ccall(dlsym(JuliaDLHandle,"rand_double"), Float64, ())
randf() = ccall(dlsym(JuliaDLHandle,"rand_float"), Float32, ())
randint() = ccall(dlsym(JuliaDLHandle,"genrand_int32"), Uint32, ())