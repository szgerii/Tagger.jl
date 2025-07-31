export TagType, @def_tagtype, get_default_tag

"""
    TagType

The abstract supertype of all tag types understood by Tagger.jl
The recommended way of defining subtypes is through the [`@def_tagtype`](@ref) macro.
"""
abstract type TagType end

"""
    get_default_tag(::Type{T}) where {T <: TagType} -> Union{<:T, Nothing}

Retrieves the default tag for a given tag type. If there is no default tag registered for the tag type, nothing is returned.
Although the recommended way of declaring and defining default tags is through the [`@def_tagtype`](@ref) macro, this function can be extended with a new method for any TagType to specify its default tag.

# Arguments
- `::Type{T <: TagType}`: The tag type to retrieve the default tag for
"""
get_default_tag(::Type{T}) where {T<:TagType} = nothing

# helper function for the @def_tagtype macros
gen_tagtype(name::Symbol) = quote
    abstract type $(esc(name)) <: TagType end

    # TODO dont allow any T to be inside Val, only Symbol values (maybe through @generated functions and a manual type check in the body)
    Tagger.eq_match(::Type{$(esc(name))}, ::Type{Val{T}}) where T = nothing
end

"""
    @def_tagtype name

Defines a new tag type without adding a default tag.
This also takes care of defining any fallback methods that might be necessary for a proper tag type definition.
The tag type will be defined in the calling scope, so make sure its name doesn't conflict with any types in the module.

# Arguments
- `name::Symbol`: The name of the tag type to define

# Examples
```jldoctest
julia> @def_tagtype MyDefaultlessTagType

julia> MyDefaultlessTagType <: TagType
true

julia> isnothing(get_default_tag(MyDefaultlessTagType))
true
"""
macro def_tagtype(name::Symbol)
    gen_tagtype(name)
end

"""
    @def_tagtype name default_tag_name

Defines a new tag type and registers a default tag for it.
This also takes care of defining any fallback methods that might be necessary for a proper tag type definition.
The tag type and the default tag will be defined in the calling scope, so make sure its name doesn't conflict with any types in the module.

# Arguments
- `name::Symbol`: The name of the tag type to define
- `default_tag_name::Symbol`: The name of the default tag for the new tag type

# Examples
```jldoctest
julia> @def_tagtype MyTagTypeWithDefault DefaultTag

julia> MyTagTypeWithDefault <: TagType
true

julia> get_default_tag(MyTagTypeWithDefault)
DefaultTag
"""
macro def_tagtype(name::Symbol, default_tag_name::Symbol)
    quote
        $(gen_tagtype(name))
        struct $(esc(default_tag_name)) <: $(esc(name)) end
        Tagger.get_default_tag(::Type{$(esc(name))}) = $(esc(default_tag_name))
    end
end
