export TagType, @def_tagtype

abstract type TagType end

get_default_tag(::Type{T}) where {T<:TagType} = nothing

gen_tagtype(name::Symbol) = quote
    abstract type $(esc(name)) <: TagType end

    # TODO dont allow any T to be inside Val, only Symbol values (maybe through @generated functions and a manual type check in the body)
    Tagger.eq_match(::Type{$(esc(name))}, ::Type{Val{T}}) where T = nothing
end

macro def_tagtype(name::Symbol)
    gen_tagtype(name)
end

macro def_tagtype(name::Symbol, default_tag_name::Symbol)
    quote
        $(gen_tagtype(name))
        struct $(esc(default_tag_name)) <: $(esc(name)) end
        Tagger.get_default_tag(::Type{$(esc(name))}) = $(esc(default_tag_name))
    end
end
