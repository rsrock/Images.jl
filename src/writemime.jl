###
### writemime
###
# only mime writeable to PNG if 2D (used by IJulia for example)
mimewritable(::MIME"image/svg+xml", img::AbstractImage) = false
mimewritable(::MIME"image/png", img::AbstractImage) = sdims(img) == 2 && timedim(img) == 0
mimewritable{C<:Colorant}(::MIME"image/png", img::AbstractArray{C}) = sdims(img) == 2 && timedim(img) == 0

# This is used for output by IJulia. Really large images can make
# display very slow, so we shrink big images.  Conversely, tiny images
# don't show up well, so in such cases we repeat pixels.
function writemime(io::IO, mime::MIME"image/png", img::AbstractImage; mapi=mapinfo_writemime(img), minpixels=10^4, maxpixels=10^6)
    assert2d(img)
    A = data(img)
    nc = ncolorelem(img)
    npix = length(A)/nc
    while npix > maxpixels
        # Big images
        A = restrict(A, coords_spatial(img))
        npix = length(A)/nc
    end
    if npix < minpixels
        # Tiny images
        fac = ceil(Int, sqrt(minpixels/npix))
        r = ones(Int, ndims(img))
        r[coords_spatial(img)] = fac
        A = repeat(A, inner=r)
    end
    imgcopy = shareproperties(img, A)
    save(Stream(format"PNG", io), imgcopy)
end

writemime(stream::IO, mime::MIME"image/png", img::AbstractImageIndexed; kwargs...) = (println(kwargs);
    writemime(stream, mime, convert(Image, img); kwargs...))
writemime{C<:Colorant}(stream::IO, mime::MIME"image/png", img::AbstractArray{C}; kwargs...) =
    writemime(stream, mime, Image(img, spatialorder=["x","y"]); kwargs...)

function mapinfo_writemime(img; maxpixels=10^6)
    if length(img) <= maxpixels
        return mapinfo_writemime_(img)
    end
    mapinfo_writemime_restricted(img)
end

to_native_color{T<:Colorant}(::Type{T}) = base_color_type(T){UFixed8}
to_native_color{T<:Color}(::Type{T}) = RGB{UFixed8}
to_native_color{T<:TransparentColor}(::Type{T}) = RGBA{UFixed8}

mapinfo_writemime_{T <:Colorant}(img::AbstractImage{T}) = Images.mapinfo(to_native_color(T), img)
mapinfo_writemime_(img::AbstractImage) = Images.mapinfo(UFixed8,img)

mapinfo_writemime_restricted{T<:Colorant}(img::AbstractImage{T}) = ClampMinMax(to_native_color(T), 0.0, 1.0)
mapinfo_writemime_restricted(img::AbstractImage) = Images.mapinfo(UFixed8, img)
