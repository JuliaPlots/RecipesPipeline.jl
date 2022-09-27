# # RecipesPipeline
module RecipesPipeline

using NaNMath
using Dates

import RecipesBase
import RecipesBase: @recipe, @series, RecipeData, is_explicit
import PlotUtils # tryrange and adapted_grid

export recipe_pipeline!
# Plots relies on these:
export SliceIt,
    DefaultsDict,
    Formatted,
    AbstractSurface,
    Surface,
    Volume,
    is3d,
    is_surface,
    needs_3d_axes,
    group_as_matrix,
    reset_kw!,
    pop_kw!,
    scale_func,
    inverse_scale_func,
    unzip,
    dateformatter,
    datetimeformatter,
    timeformatter
# API
export warn_on_recipe_aliases,
    splittable_attribute,
    split_attribute,
    process_userrecipe!,
    get_axis_limits,
    is_axis_attribute,
    type_alias,
    plot_setup!,
    slice_series_attributes!,
    process_sliced_series_attributes!

include("utils.jl")
include("api.jl")
include("series.jl")
include("group.jl")
include("user_recipe.jl")
include("type_recipe.jl")
include("plot_recipe.jl")
include("series_recipe.jl")
include("recipes.jl")


"""
    recipe_pipeline!(plt, plotattributes, args)

Recursively apply user recipes, type recipes, plot recipes and series recipes to build a
list of `Dict`s, each corresponding to a series. At the beginning, `plotattributes`
contains only the keyword arguments passed in by the user. Then, add all series to the plot
object `plt` and return it.
"""
function recipe_pipeline!(plt, plotattributes, args)
    @nospecialize
    plotattributes[:plot_object] = plt

    # --------------------------------
    # "USER RECIPES"
    # --------------------------------

    # process user and type recipes
    kw_list = _process_userrecipes!(plt, plotattributes, args)

    # --------------------------------
    # "PLOT RECIPES"
    # --------------------------------

    # The "Plot recipe" acts like a series type, and is processed before the plot layout
    # is created, which allows for setting layouts and other plot-wide attributes.
    # We get inputs which have been fully processed by "user recipes" and "type recipes",
    # so we can expect standard vectors, surfaces, etc.  No defaults have been set yet.

    kw_list = _process_plotrecipes!(plt, kw_list)

    # --------------------------------
    # Plot/Subplot/Layout setup
    # --------------------------------

    plot_setup!(plt, plotattributes, kw_list)

    # At this point, `kw_list` is fully decomposed into individual series... one KW per
    # series. The next step is to recursively apply series recipes until the backend
    # supports that series type.

    # --------------------------------
    # "SERIES RECIPES"
    # --------------------------------

    _process_seriesrecipes!(plt, kw_list)

    # --------------------------------
    # Return processed plot object
    # --------------------------------

    return plt
end

#=
function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol, Any},AbstractMatrix{T} where T})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol, Any},AbstractVector{T} where T,AbstractVector{T} where T,Function})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol, Any},Function,Number,Number})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol, Any},GroupBy,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol, Any},Type{SliceIt},Any,Any,Any})
    Base.precompile(Tuple{typeof(RecipesBase.apply_recipe),AbstractDict{Symbol, Any},Vector{Function},Number,Number})
    Base.precompile(Tuple{typeof(_apply_type_recipe),Any,AbstractArray,Any})
    Base.precompile(Tuple{typeof(_apply_type_recipe),Any,Surface,Any})
    Base.precompile(Tuple{typeof(_compute_xyz),Vector{Float64},Function,Nothing,Bool})
    Base.precompile(Tuple{typeof(_extract_group_attributes),Vector{String},Vector{Float64}})
    Base.precompile(Tuple{typeof(_map_funcs),Function,StepRangeLen{Float64, Base.TwicePrecision{Float64}, Base.TwicePrecision{Float64}}})
    Base.precompile(Tuple{typeof(_process_seriesrecipe),Any,Any})
    Base.precompile(Tuple{typeof(_process_seriesrecipes!),Any,Any})
    Base.precompile(Tuple{typeof(_scaled_adapted_grid),Function,Symbol,Symbol,Float64,Irrational{:π}})
    Base.precompile(Tuple{typeof(_series_data_vector),Int64,Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Matrix{Float64},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Surface{Matrix{Int64}},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{AbstractVector{Float64}},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{Function},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{Int64},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{Real},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{String},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{Union{Missing, Int64}},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{Vector{Float64}},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(_series_data_vector),Vector{Vector{T} where T},Dict{Symbol, Any}})
    Base.precompile(Tuple{typeof(recipe_pipeline!),Any,Any,Any})
    Base.precompile(Tuple{typeof(unzip),Vector{Tuple{Float64, Float64}}})
    Base.precompile(Tuple{typeof(unzip),Vector{Tuple{Int64, Int64}}})
    Base.precompile(Tuple{typeof(unzip),Vector{Tuple{Int64, Real}}})
    Base.precompile(Tuple{typeof(unzip),Vector{Tuple{Vector{Float64}, Vector{Float64}}}})
end
=#

using SnoopPrecompile
@precompile_setup begin
    plotattributes = Dict{Symbol, Any}[
        Dict(:x => 1, :y => "", :z => nothing, :seriestype => :path),
        Dict(:x => 1, :y => "", :z => nothing, :seriestype => :surface),
    ]
    __func1(x) = x
    __func2(x, y) = x + y
    @precompile_all_calls begin
        _compute_xyz(__func1, 1:2, 1:2)
        _compute_xyz(1:2, __func1, 1:2)
        _compute_xyz(1:2, 1:2, __func2)
        _compute_xyz(1:2, 1:2, [1 2;3 4])
        _extract_group_attributes([1, 2])
        _extract_group_attributes(([1], [2]))
        _extract_group_attributes((; a = [1], b = [2]))
        _extract_group_attributes(Dict("a" => [1], "b" => [2]))
        mats = (Int[1 2;3 4], Float64[1 2;3 4])
        surfs = Surface.(mats)
        vols = Volume(ones(Int, 1, 2, 3)), Volume(ones(Float64, 1, 2, 3))
        for pl_attr ∈ plotattributes 
            _series_data_vector(1, pl_attr)
            _series_data_vector([1], pl_attr)
            _series_data_vector(["a"], pl_attr)
            _series_data_vector([1 2], pl_attr)
            _series_data_vector(["a" "b"], pl_attr)
            _series_data_vector.(surfs, Ref(pl_attr))
            _apply_type_recipe.(Ref(pl_attr), surfs, Ref(:x))
            _apply_type_recipe.(Ref(pl_attr), mats, Ref(:x))
            _map_funcs(identity, [1, 2])
            _map_funcs([identity, identity], [1, 2])
            unzip([(1.0, 1.0)])
            unzip([(1, 1)])
            unzip([(1, 1.0)])
            unzip([([1.0], [2.0])])
            # _process_seriesrecipe(nothing, pl_attr)
            # recipe_pipeline!(plt, [1, 2], ["foo", "bar"])
        end
    end
end

end
