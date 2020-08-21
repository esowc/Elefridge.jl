const DEFAULT_BLOCKSIZE=2^14

function bittranspose!( ::Type{UIntT},				# UInt equiv to T
						At::AbstractArray{T},		# transposed array
						A::AbstractArray{T};		# original array
						blocksize::Int=DEFAULT_BLOCKSIZE) where {UIntT<:Unsigned,T}

	@boundscheck size(A) == size(At) || throw("Input arrays must be of same size.")
	@boundscheck sizeof(UIntT) == sizeof(T) || throw("Array elements do not match in bitsize.")

    nbits = sizeof(T)*8
    N = length(A)

    # At .= zero(T)                 	    # make sure output array is zero
    nblocks = (N-1) ÷ blocksize + 1			# number of blocks

    for nb in 1:nblocks

        lastindex = min(nb*blocksize,N)

        Ablock = view(A,(nb-1)*blocksize+1:lastindex)
        Atblock = view(At,(nb-1)*blocksize+1:lastindex)

        i = 0   # counter for transposed bits
        for bi in 1:nbits
            # mask to extract bit bi in each element of A
            mask = one(UIntT) << (nbits-bi)

			# walk through elements in A first, then change bit-position
			# this comes with disadvantage that A has to be read nbits-times
			# but allows for more natural indexing, as all the sign bits are
			# read first, and so on.

            for (ia,a) in enumerate(Ablock)
				ui = reinterpret(UIntT,a)
                # mask non-bi bits and
                # (1) shift by nbits-bi >> to the right, either 0x0 or 0x1
                # (2) shift by (nbits-1) - (i % nbits) << to the left
                # combined this is: >> ((i % nbits)-bi+1)
                bit = (ui & mask) >> ((i % nbits)-bi+1)

                # the first nbits elements go into same b in B, then next b
				idx = (i ÷ nbits) + 1
				@inbounds atui = reinterpret(UIntT,Atblock[idx])
                @inbounds Atblock[idx] = reinterpret(T,atui | bit)
                i += 1
            end
        end
    end

    return At
end

function bittranspose(A::AbstractArray{T};kwargs...) where T
	UIntT = whichUInt(T)
	At = fill(reinterpret(T,zero(UIntT)),size(A))
	bittranspose!(UIntT,At,A;kwargs...)
	return At
end

function bitbacktranspose!(	::Type{UIntT},				# UInt equiv to T
							A::AbstractArray{T},		# backtransposed output
							At::AbstractArray{T};		# transposed input
							blocksize::Int=DEFAULT_BLOCKSIZE) where {UIntT<:Unsigned,T}

	@boundscheck size(A) == size(At) || throw("Input arrays must be of same size.")
	@boundscheck sizeof(UIntT) == sizeof(T) || throw("Array elements do not match in bitsize.")

    nbits = sizeof(T)*8
    N = length(At)

    # A .= zero(T)                 	    # make sure output array is zero
    nblocks = (N-1) ÷ blocksize + 1		# number of blocks

    for nb in 1:nblocks

        lastindex = min(nb*blocksize,N)

        Ablock = view(A,(nb-1)*blocksize+1:lastindex)
        Atblock = view(At,(nb-1)*blocksize+1:lastindex)

		nelements = length(Atblock)	# = blocksize except for the last
									# block where usually smaller

        i = 0   # counter for transposed bits
		for (ia,a) in enumerate(Atblock)
			ui = reinterpret(UIntT,a)

        	for bi in 1:nbits
            	# mask to extract bit bi in each element of A
            	mask = one(UIntT) << (nbits-bi)

                # mask non-bi bits and
                # (1) shift by nbits-bi >> to the right, either 0x0 or 0x1
                # (2) shift by (nbits-1) - (i ÷ nblockfloat) << to the left
                # combined this is: >> ((i ÷ nbits)-bi+1)
                bit = (ui & mask) >> ((i ÷ nelements)-bi+1)

                # the first nbits elements go into same a in A, then next a
				idx = (i % nelements) + 1
				@inbounds aui = reinterpret(UIntT,Ablock[idx])
				@inbounds Ablock[idx] = reinterpret(T,aui | bit)
                i += 1
            end
        end
    end

    return A
end

function bitbacktranspose(At::AbstractArray{T};kwargs...) where T
	UIntT = whichUInt(T)
	A = fill(reinterpret(T,zero(UIntT)),size(At))
	bitbacktranspose!(UIntT,A,At;kwargs...)
	return A
end

# function Base.BitMatrix(A::Array{T,1}) where T
# 	isbitstype(eltype(A)) || error("Only bitstype for elements of A allowed.
# 									$(eltype(A)) provided")
# 	height = 8 * sizeof(eltype(A))
# 	dims = (height, length(A))
# 	data_elems = cld(sizeof(A), 8)
# 	bitarr = Base.BitMatrix(undef, dims)
# 	bitarr.chunks = unsafe_wrap(Array, Ptr{UInt}(pointer(A)), (data_elems,))
# 	return bitarr
# end
#
# function foo(x::Array)
# 	isbitstype(eltype(x)) || error("Bad!")
# 	height = 8 * sizeof(eltype(x))
# 	dims = (height, length(x))
# 	data_elems = cld(sizeof(x), 8)
# 	bitarr = Base.BitMatrix(undef, dims)
# 	bitarr.chunks = unsafe_wrap(Array, Ptr{UInt}(pointer(x)), (data_elems,))
# 	return bitarr
# end
