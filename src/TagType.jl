export TagType, DefaultTag, @def_tagtype

abstract type TagType end

struct DefaultTag <: TagType end

gen_tagtype(name::Symbol) = quote
    abstract type $(esc(name)) <: TagType end

    # TODO dont allow any T to be inside Val, only Symbol values (maybe through @generated functions and a manual type check in the body)
    TagMatching.eq_match(::Type{$(esc(name))}, ::Type{Val{T}}) where T = nothing
end

macro def_tagtype(name::Symbol)
    gen_tagtype(name)
end

macro def_tagtype(name::Symbol, default_tag_name::Symbol)
    quote
        $(gen_tagtype(name))
        struct $(esc(default_tag_name)) <: $(esc(name)) end
        TagMatching.get_default_tag(::Type{$(esc(name))}) = $(esc(default_tag_name))
    end
end
