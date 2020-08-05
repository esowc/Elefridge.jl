function bitcount(A::Array{T},b::Int) where {T<:Unsigned}
    N = sizeof(T)*8             # number of bits in T
    @boundscheck b <= N || throw(BoundsError("Count bit $b for $T is invalid."))
    n = 0                       # counter
    shift = N-b                 # shift desired bit b
    mask = one(T) << shift
    for a in A                      # mask everything but b and shift
        n += (a & mask) >> shift    # to have either 0x00 or 0x01
    end
    return n
end

bitcount(A::Array{T},b::Int) where {T<:Union{Signed,AbstractFloat}} =
    bitcount(reinterpret.(whichUInt(T),A),b)

function bitcount(A::Array{T}) where {T<:Union{Unsigned,Signed,AbstractFloat}}
    N = 8*sizeof(T)
    n = fill(0,N)
    for b in 1:N
        n[b] = bitcount(A,b)
    end
    return n
end

function bitcountentropy(A::AbstractArray)
    N = prod(size(A))
    p = bitcount(A) / N
    e = [abs(entropy([pi,1-pi],2)) for pi in p]
    return e
end

function bitpaircount(A::Array{T},b::Int) where {T<:Unsigned}
    N = sizeof(T)*8             # number of bits in T
    @boundscheck b <= N || throw(BoundsError("Count bit $b for $T is invalid."))
    n = [0,0,0,0]               # counter for 00,01,10,11
    shift = N-b-1               # shift to the 2nd last position either 0x00,0x10
    shift2 = N-b                # shift to last position 0x0 or 0x1
    mask = one(T) << shift2     # mask everything except b

    # a1 is bit from previous entry in A, a2 is the current
    # a1 is shifted to sit in the 2nd last position
    # a2 sits in the last position
    a1 = (A[1] & mask) >> shift
    for a in A[2:end]
        a2 = (a & mask) >> shift2
        n[(a1 | a2)+1] += 1
        a1 = a2 << 1
    end
    return n
end

bitpaircount(A::Array{T},b::Int) where {T<:Union{Signed,AbstractFloat}} =
    bitpaircount(reinterpret.(whichUInt(T),A),b)

function bitpaircount(A::Array{T}) where {T<:Union{Unsigned,Signed,AbstractFloat}}
    N = 8*sizeof(T)         # number of bits in T
    n = fill(0,4,N)         # store the 4 possible pair counts for every bit
    for b in 1:N
        n[:,b] = bitpaircount(A,b)
    end
    return n
end

function bitcondprobability(A::Array{T}) where {T<:Union{Unsigned,Signed,AbstractFloat}}
    N = prod(size(A[2:end]))        # elements in array (A[1] is )
    n1 = bitcount(A[1:end-1])
    n0 = N.-n1
    npair = bitpaircount(A)
    pcond = similar(npair,Float64)
    pcond[1,:] = npair[1,:] ./ n0
    pcond[2,:] = npair[2,:] ./ n0
    pcond[3,:] = npair[3,:] ./ n1
    pcond[4,:] = npair[4,:] ./ n1
    return pcond
end

function bitcpentropy(A::Array{T}) where {T<:Union{Unsigned,Signed,AbstractFloat}}
    pcond = bitcondprobability(A)
    pcond[isnan.(pcond)] .= 0
    pcond /= 2
    e = [abs(entropy(pcond[:,i],2)) for i in 1:size(pcond)[2]]
    return e
end

function bitinformation(A::Array{T}) where {T<:Union{Unsigned,Signed,AbstractFloat}}
    N = prod(size(A[2:end]))        # elements in array
    n1 = bitcount(A[1:end-1])       # occurences of bit = 1
    n0 = N.-n1                      # occurences of bit = 0
    q0 = n0/N                       # respective probabilities
    q1 = n1/N

    npair = bitpaircount(A)
    pcond = similar(npair,Float64)      # preallocate conditional probability

    pcond[1,:] = npair[1,:] ./ n0       # p(0|0) = n(00)/n(0)
    pcond[2,:] = npair[2,:] ./ n0       # p(1|0) = n(01)/n(0)
    pcond[3,:] = npair[3,:] ./ n1       # p(0|1) = n(10)/n(1)
    pcond[4,:] = npair[4,:] ./ n1       # p(1|1) = n(11)/n(1)

    # set NaN (occurs when occurences n=0) 0*-Inf = 0 here.
    pcond[isnan.(pcond)] .= 0

    # unconditional entropy
    H = [entropy([q0i,q1i],2) for (q0i,q1i) in zip(q0,q1)]

    # conditional entropy given bit = 0, bit = 1
    H0 = [entropy([p00,p01],2) for (p00,p01) in zip(pcond[1,:],pcond[2,:])]
    H1 = [entropy([p10,p11],2) for (p10,p11) in zip(pcond[3,:],pcond[4,:])]

    # Information content
    I = @. H - q0*H0 - q1*H1

    return I
end
