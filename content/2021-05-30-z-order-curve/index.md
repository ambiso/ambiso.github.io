+++
title = "Z-Order Curve Visualization"
[taxonomies]
categories = ["misc"]
+++

A visualization of a 3D [Z-order curve](https://en.wikipedia.org/wiki/Z-order_curve).
Doesn't really work on mobile - use the mouse to rotate the view.

A friend of mine asked me about optimizing matrix multiplication.
One way to obtain better cache locality is to use space filling curves.

<iframe src="zoc.html" width="800" height="800">
</iframe>

I made this visualization using [WGLMakie](https://github.com/JuliaPlots/WGLMakie.jl) and [JSServe.jl](https://github.com/SimonDanisch/JSServe.jl) in [Julia](https://julialang.org/).
We can convert between points in $$\{0,\ldots,2^{3 \cdot n}-1\}$$ and $$\left(\{0,\ldots,2^n\}\right)^3$$ by interleaving the bits.
This is described in more detail on the [Wikipedia](https://en.wikipedia.org/wiki/Z-order_curve#Coordinate_values) page.
The `zoc2p` function implements this mapping.

```julia
function zoc2p(zoc, digits_per_coordinate, dim)
    p = digits(zoc, base=2, pad=dim * digits_per_coordinate)
    mapslices(reshape(p, :, digits_per_coordinate); dims=2) do x
        sum(2^(i-1) * x for (i,x) in enumerate(x))
    end
end
```
Here, `dim` is the number of dimensions of the z-order curve and `digits_per_coordinate` corresponds to $$n$$.
We then enumerate all points in $$\{0,\ldots,2^{3 \cdot n}-1\}$$ and send them through the function to obtain the corresponding point in 3D space:

```julia
v = vcat([zoc2p(i, digits_per_coordinate, dim)' for i=0:2^(digits_per_coordinate*dim)-1]...)
```

Here's the full plotting function:

```julia
function plt()
    set_theme!(resolution=(800, 800))

    app = App() do s::Session
        digits_per_coordinate = 3
        dim = 3
        v = vcat([zoc2p(i, digits_per_coordinate, dim)' for i=0:2^(digits_per_coordinate*dim)-1]...)

        xs = v[:, 1]
        ys = v[:, 2]
        zs = v[:, 3]
        progress = (0:length(xs)-1)./(length(xs)-1)

        fig, ax, splot = lines(xs, ys, zs, linewidth=50, color=progress, colormap=:rainbow)

        DOM.div(fig)
    end

    page = Page(offline=true, exportable=true)
    page_html = sprint() do io
        show(io, MIME"text/html"(), page)
        show(io, MIME"text/html"(), app)
    end

    write("export/index.html", page_html)
end
```

`JSServe` then allows us to export the plot as a static webpage, and it's the one you see above embedded as an `iframe`!