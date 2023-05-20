using ..NaturalNeighbours
using CairoMakie
using ReferenceTests

## The data 
rng = StableRNG(123)
f = (x, y) -> sin(x * y) - cos(x - y) * exp(-(x - y)^2)
x = vec([(i - 1) / 9 for i in (1, 3, 4, 5, 8, 9, 10), j in (1, 2, 3, 5, 6, 7, 9, 10)])
y = vec([(j - 1) / 9 for i in (1, 3, 4, 5, 8, 9, 10), j in (1, 2, 3, 5, 6, 7, 9, 10)])
z = f.(x, y)

## The interpolant and grid 
itp = interpolate(x, y, z; derivatives=true)
xg = LinRange(0, 1, 100)
yg = LinRange(0, 1, 100)
_x = vec([x for x in xg, _ in yg])
_y = vec([y for _ in xg, y in yg])
exact = f.(_x, _y)

## Evaluate some interpolants 
sibson_vals = itp(_x, _y; method=Sibson())
triangle_vals = itp(_x, _y; method=Triangle())
laplace_vals = itp(_x, _y; method=Laplace())
sibson_1_vals = itp(_x, _y; method=Sibson(1))
nearest = itp(_x, _y; method=Nearest())

## Plot 
function plot_2d(i, j, title, vals, xg, yg, x, y, show_scatter=true)
    ax = Axis(fig[i, j], xlabel="x", ylabel="y", width=600, height=600, title=title, titlealign=:left)
    contourf!(ax, xg, yg, reshape(vals, (length(xg), length(yg))), color=vals, colormap=:viridis, levels=-1:0.05:0, extendlow=:auto, extendhigh=:auto)
    show_scatter && scatter!(ax, x, y, color=:red, markersize=14)
end
function plot_3d(i, j, title, vals, xg, yg)
    ax = Axis3(fig[i, j], xlabel="x", ylabel="y", width=600, height=600, title=title, titlealign=:left)
    surface!(ax, xg, yg, reshape(vals, (length(xg), length(yg))), color=vals, colormap=:viridis, levels=-1:0.05:0, extendlow=:auto, extendhigh=:auto)
end

fig = Figure(fontsize=36)
plot_2d(1, 1, "(a): Sibson", sibson_vals, xg, yg, x, y)
plot_2d(1, 2, "(b): Triangle", triangle_vals, xg, yg, x, y)
plot_2d(1, 3, "(c): Laplace", laplace_vals, xg, yg, x, y)
plot_2d(1, 4, "(d): Sibson-1", sibson_1_vals, xg, yg, x, y)
plot_2d(1, 5, "(e): Nearest", nearest, xg, yg, x, y)
plot_2d(1, 6, "(f): Exact", exact, xg, yg, x, y, false)
plot_3d(2, 1, " ", sibson_vals, xg, yg)
plot_3d(2, 2, " ", triangle_vals, xg, yg)
plot_3d(2, 3, " ", laplace_vals, xg, yg)
plot_3d(2, 4, " ", sibson_1_vals, xg, yg)
plot_3d(2, 5, " ", nearest, xg, yg)
plot_3d(2, 6, " ", exact, xg, yg)
resize_to_layout!(fig)
fig

@test_reference normpath(@__DIR__, "../..", "example.png") fig