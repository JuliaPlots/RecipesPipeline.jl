abstract type AbstractConsumer end

# this should live in Plots

struct PlotsConsumer <: AbstractConsumer end

# this stuff should live in Makie

struct MakieConsumer <: AbstractConsumer end

const makie_backend_seriestypes = Dict{Symbol, Function}(:scatter => scatter!, :lines => lines!, :path => lines!, :path3d => lines!, :shape => poly!, #=...=#)

function is_seriestype_supported(::MakieConsumer, st::Symbol)
    return haskey(makie_backend_seriestypes, st)
end

function send_to_backend(::MakieConsumer, st::Symbol, rd::RecipeData)
     # TODO how should we implement this?
end
