module NaturalNeighbours

import DelaunayTriangulation: DelaunayTriangulation,
    triangulate,
    integer_type,
    num_points,
    InsertionEventHistory,
    add_point!,
    each_added_triangle,
    indices,
    initialise_event_history,
    Triangulation,
    triangulate,
    is_boundary_index,
    construct_triangle,
    Adjacent,
    add_triangle!,
    edge_type,
    get_adjacent,
    num_triangles,
    number_type,
    previndex_circular,
    nextindex_circular,
    get_point,
    triangle_circumcenter,
    num_points,
    number_type,
    getxy,
    polygon_features,
    getpoint,
    num_solid_vertices,
    has_ghost_triangles,
    add_ghost_triangles!,
    is_collinear,
    has_boundary_nodes,
    get_triangulation,
    rotate_ghost_triangle_to_standard_form,
    is_on,
    is_degenerate,
    point_position_relative_to_triangle,
    point_position_on_line_segment,
    point_position_relative_to_line,
    is_ghost_triangle,
    distance_to_polygon,
    initial,
    terminal,
    find_edge,
    triangle_type,
    is_boundary_triangle,
    replace_boundary_triangle_with_ghost_triangle,
    each_solid_triangle,
    jump_and_march,
    jump_to_voronoi_polygon,
    iterated_neighbourhood,
    iterated_neighbourhood!
import ChunkSplitters: chunks
using ElasticArrays

num_points(::NTuple{N,F}) where {N,F} = N
getpoint(p::NTuple{N,F}, i::Integer) where {N,F} = p[i]

export interpolate

include("data_structures/natural_coordinates.jl")
include("data_structures/interpolation_cache.jl")
include("data_structures/interpolant.jl")
include("data_structures/derivative_cache.jl")
include("data_structures/differentiator.jl")

include("interpolation/extrapolation.jl")
include("interpolation/interpolate.jl")
include("interpolation/coordinates/main.jl")
include("interpolation/coordinates/sibson.jl")
include("interpolation/coordinates/triangle.jl")
include("interpolation/coordinates/nearest.jl")
include("interpolation/coordinates/laplace.jl")

include("differentiation/generate.jl")
include("differentiation/methods/direct.jl")
include("utils.jl")

end # module NaturalNeighbours