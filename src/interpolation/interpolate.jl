"""
    interpolate(tri::Triangulation, z; gradient=nothing, hessian=nothing, derivatives=false, kwargs...)
    interpolate(points, z; gradient=nothing, hessian=nothing, derivatives=false, kwargs...)
    interpolate(x::AbstractVector, y::AbstractVector, z; gradient=nothing, hessian=nothing, derivatives=false, kwargs...)

Construct an interpolant over the data `z` at the sites defined by the triangulation `tri` (or `points`, or `(x, y)`). See the Output 
section for a description of how to use the interpolant `itp`.

# Keyword Arguments 
- `gradient=nothing`: The gradients at the corresponding data sites of `z`. Will be generated if `isnothing(gradient)` and `derivatives==true`.
- `hessian=nothing`: The hessians at the corresponding data sites of `z`. Will be generated if `isnothing(hessian)` and `derivatives==true`.
- `derivatives=false`: Whether to generate derivatives at the data sites of `z`. See also [`generate_derivatives`](@ref).
- `kwargs...`: Keyword arguments passed to [`generate_derivatives`](@ref).

# Output 
The returned value is a `NaturalNeighboursInterpolant` struct. This struct is callable, with the following methods defined:

    (itp::NaturalNeighboursInterpolant)(x, y, id::Integer=1; parallel=false, method=Sibson(), project = true, kwargs...)
    (itp::NaturalNeighboursInterpolant)(vals::AbstractVector, x::AbstractVector, y::AbstractVector; parallel=true, method=Sibson(), project = true, kwargs...)
    (itp::NaturalNeighboursInterpolant)(x::AbstractVector, y::AbstractVector; parallel=true, method=Sibson(), project = true, kwargs...)

1. The first method is for scalars, with `id` referring to a thread id. 
2. This method is an in-place method for vectors, storing `itp(x[i], y[i])` into `vals[i]`. 
3. This method is similar to (2), but `vals` is constructed and returned. 

In each method, `method` defines the method used for evaluating the interpolant, which is some [`AbstractInterpolator`](@ref). For the first 
method, `parallel` is ignored, but for the latter two methods it defines whether to use multithreading or not for evaluating the interpolant at 
all the points. The `kwargs...` argument is passed into `add_point!` from DelaunayTriangulation.jl, e.g. you could pass some `rng`. Lastly, 
the `project` argument determines whether extrapolation is performed by projecting any exterior points onto the boundary of the convex hull 
of the data sites and performing two-point interpolation, or to simply replaced any extrapolated values with `NaN`.
"""
interpolate(tri::Triangulation, z; gradient=nothing, hessian=nothing, kwargs...) = NaturalNeighboursInterpolant(tri, z, gradient, hessian; kwargs...)

"""
    abstract type AbstractInterpolator{D}

Abstract type for defining the method used for evaluating an interpolant. `D` is, roughly, defined to be 
the smoothness at the data sites (currently only relevant for `Sibson`). The available subtypes are:

- `Sibson(d)`: Interpolate via the Sibson interpolant, with `C(d)` continuity at the data sites. Only defined for `D ∈ (0, 1)`. If `D == 1`, gradients must be provided.
- `Triangle(d)`: Interpolate based on vertices of the triangle that the point resides in, with `C(0)` continuity at the data sites. `D` is ignored.
- `Nearest(d)`: Interpolate by returning the function value at the nearest data site. `D` doesn't mean much here (it could be `D = ∞`), and so it is ignored and replaced with `0`.
- `Laplace(d)`: Interpolate via the Laplace interpolant, with `C(0)` continuity at the data sites. `D` is ignored.
"""
abstract type AbstractInterpolator{D} end
@doc """
    Sibson(d=0)

Interpolate using Sibson's coordinates with `C(d)` continuity at the data sites.
""" struct Sibson{D} <: AbstractInterpolator{D}
    Sibson(d=0) = d ∈ (0, 1) ? new{d}() : throw(ArgumentError("The Sibson interpolant is only defined for d ∈ (0, 1)."))
end
struct Triangle{D} <: AbstractInterpolator{D} end
struct Nearest{D} <: AbstractInterpolator{D} end
struct Laplace{D} <: AbstractInterpolator{D} end
@doc """
    Triangle()

Interpolate using a piecewise linear interpolant over the underlying triangulation.
""" Triangle(d=0) = Triangle{0}()
@doc """
    Nearest()

Interpolate by taking the function value at the nearest data site.
""" Nearest(d=0) = Nearest{0}()
@doc """
    Laplace()

Interpolate using Laplace's coordinates.
""" Laplace(d=0) = Laplace{0}()

iwrap(s::AbstractInterpolator) = s
function iwrap(s::Symbol)
    if s == :sibson
        return Sibson()
    elseif s == :triangle
        return Triangle()
    elseif s == :nearest
        return Nearest()
    elseif s == :laplace
        return Laplace()
    else
        throw(ArgumentError("Unknown interpolator: $s"))
    end
end

function interpolate(points, z; gradient=nothing, hessian=nothing, kwargs...)
    tri = triangulate(points, delete_ghosts=false)
    return interpolate(tri, z; gradient, hessian, kwargs...)
end
function interpolate(x::AbstractVector, y::AbstractVector, z; gradient=nothing, hessian=nothing, kwargs...)
    @assert length(x) == length(y) == length(z) "x, y, and z must have the same length."
    points = [(ξ, η) for (ξ, η) in zip(x, y)]
    return interpolate(points, z; gradient, hessian, kwargs...)
end

function _eval_natural_coordinates(coordinates, indices, z)
    val = zero(eltype(z))
    for (λ, k) in zip(coordinates, indices)
        zₖ = z[k]
        val += λ * zₖ
    end
    return val
end

function _eval_natural_coordinates(nc::NaturalCoordinates{F}, z) where {F}
    coordinates = get_coordinates(nc)
    indices = get_indices(nc)
    return _eval_natural_coordinates(coordinates, indices, z)
end

function _eval_natural_coordinates(nc::NaturalCoordinates{F}, z, gradients, tri) where {F}
    sib0 = _eval_natural_coordinates(nc, z)
    coordinates = get_coordinates(nc)
    if length(coordinates) ≤ 2 # 2 means extrapolation, 1 means we're evaluating at a data site 
        return sib0
    end
    ζ, α, β = _compute_sibson_1_coordinates(nc, tri, z, gradients)
    num = α * sib0 + β * ζ
    den = α + β
    return num / den
end

function _eval_interp(method, itp::NaturalNeighboursInterpolant, p, cache; kwargs...)
    tri = get_triangulation(itp)
    nc = compute_natural_coordinates(method, tri, p, cache; kwargs...)
    z = get_z(itp)
    return _eval_natural_coordinates(nc, z)
end

function _eval_interp(method::Sibson{1}, itp::NaturalNeighboursInterpolant, p, cache; kwargs...) # # has to be a different form since Sib0 blends two functions 
    gradients = get_gradient(itp)
    if isnothing(gradients)
        throw(ArgumentError("Gradients must be provided for Sibson-1 interpolation. Consider using e.g. interpolate(tri, z; derivatives = true)."))
    end
    tri = get_triangulation(itp)
    nc = compute_natural_coordinates(Sibson(), tri, p, cache; kwargs...)
    z = get_z(itp)
    return _eval_natural_coordinates(nc, z, gradients, tri)
end

function (itp::NaturalNeighboursInterpolant)(x, y, id::Integer=1; parallel=false, method=Sibson(), kwargs...)
    p = (x, y)
    cache = get_neighbour_cache(itp, id)
    return _eval_interp(iwrap(method), itp, p, cache; kwargs...)
end

function (itp::NaturalNeighboursInterpolant)(vals::AbstractVector, x::AbstractVector, y::AbstractVector; parallel=true, method=Sibson(), kwargs...)
    @assert length(x) == length(y) == length(vals) "x, y, and vals must have the same length."
    if !parallel
        for i in eachindex(x, y)
            vals[i] = itp(x[i], y[i], 1; method, kwargs...)
        end
    else
        caches = get_neighbour_cache(itp)
        nt = length(caches)
        chunked_iterator = chunks(vals, nt)
        Threads.@threads for (xrange, chunk_id) in chunked_iterator
            for i in xrange
                vals[i] = itp(x[i], y[i], chunk_id; method, kwargs...)
            end
        end
    end
    return nothing
end
function (itp::NaturalNeighboursInterpolant)(x::AbstractVector, y::AbstractVector; parallel=true, method=Sibson(), kwargs...)
    @assert length(x) == length(y) "x and y must have the same length."
    n = length(x)
    tri = get_triangulation(itp)
    F = number_type(tri)
    vals = zeros(F, n)
    itp(vals, x, y; method, parallel, kwargs...)
    return vals
end