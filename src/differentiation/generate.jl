abstract type AbstractDifferentiator end
struct Direct <: AbstractDifferentiator end
wrap_differentiator(d::AbstractDifferentiator) = d
function wrap_differentiator(d)
    if d == :direct
        return Direct()
    else
        throw(ArgumentError("Unknown differentiator: $d"))
    end
end

function generate_derivatives(points, z, order; method=:direct, parallel=true, kwargs...)
    tri = triangulate(points, delete_ghosts=false)
    return generate_derivatives(tri, z, order; method, parallel)
end
function generate_derivatives(x::AbstractVector, y::AbstractVector, z, order; method=:direct, parallel=true, kwargs...)
    @assert length(x) == length(y) == length(z) "x, y, and z must have the same length."
    points = [(ξ, η) for (ξ, η) in zip(x, y)]
    return generate_derivatives(points, z, order; method, parallel)
end
function generate_derivatives(tri::Triangulation, z, order; parallel=true)
    differentiator = NaturalNeighboursDifferentiator(tri, z)
    return generate_derivatives(differentiator, order; method, parallel)
end

function generate_derivatives(differentiator::NaturalNeighboursDifferentiator, order; method=:direct, parallel=true, kwargs...)
    @assert order ∈ (1, 2) "Only gradients and Hessians can be estimated."
    method = wrap_differentiator(method)
    if order == 1
        return generate_gradients(differentiator, method; parallel)
    else
        return generate_gradients_and_hessians(differentiator, method; parallel)
    end
end

function generate_gradients(differentiator, method::AbstractDifferentiator; parallel=true, kwargs...)
    method = wrap_differentiator(method)
    tri = get_triangulation(differentiator)
    z = get_z(differentiator)
    F = number_type(tri)
    gradients = Vector{NTuple{2,F}}(undef, length(z))
    if !parallel
        cache = get_cache(differentiator, 1)
        for i in eachindex(z)
            p = get_point(tri, i)
            gradients[i] = eval_gradient(method, tri, z, p, cache; kwargs...)
        end
    else
        caches = get_cache(differentiator)
        nt = length(caches)
        chunked_iterator = chunks(gradients, nt)
        Threads.@threads for (zrange, chunk_id) in chunked_iterator
            cache = caches[chunk_id]
            for i in eachindex(zrange)
                p = get_point(tri, i)
                gradients[i] = eval_gradient(method, tri, z, p, cache; kwargs...)
            end
        end
    end
    return gradients
end

function generate_gradients_and_hessians(differentiator, method::AbstractDifferentiator; parallel=true, kwargs...)
    method = wrap_differentiator(method)
    tri = get_triangulation(differentiator)
    z = get_z(differentiator)
    F = number_type(tri)
    gradients = Vector{NTuple{2,F}}(undef, length(z))
    hessians = Vector{NTuple{3,F}}(undef, length(z))
    if !parallel
        cache = get_cache(differentiator, 1)
        for i in eachindex(z)
            gradients[i], hessians[i] = eval_gradient_and_hessian(method, tri, z, i, cache, kwargs...)
        end
    else
        caches = get_cache(differentiator)
        nt = length(caches)
        chunked_iterator = chunks(gradients, nt)
        Threads.@threads for (zrange, chunk_id) in chunked_iterator
            cache = caches[chunk_id]
            for i in eachindex(zrange)
                gradients[i], hessians[i] = eval_gradient_and_hessian(method, tri, z, i, cache, kwargs...)
            end
        end
    end
    return gradients, hessians
end