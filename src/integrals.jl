
function g_tensor(b::Basis; alpha=1.0, scale=-1.0)
    # g_ijnm = J_ijnm - K_injm
    tmp = erig(b,1,1; alpha=alpha, scale=scale)
    l = length(b)
    g =zeros(typeof(tmp), l, l, l, l)
    Threads.@threads for i in 1:l
        for j in 1:l, n in 1:l, m in 1:l
            g[i,j,n,m] = erig(b, i, j, n, m) - erig(b, i, n, j, m)
        end
    end
    return g
end

function eri(b::Basis, i::Int, j::Int, n::Int, m::Int; tmax=1000)
    # Basis functions are orthogonal
    i != j && return 0
    n != m && return 0
    return eri(b, i, n; tmax=tmax)
end

function eri(b::Basis, i::Int, j::Int; tmax=1000, threshold=0.01)
    f(t, x) = 2/√π *exp(-t^2*x^2)
    r = abs(b[i]-b[j])
    r > threshold && return 1/r
    return quadgk( t->f(t,r), 0, tmax; rtol=1e-12 )[1]
end


"""
    erig(b::Basis, i::Int, j::Int; alpha=1.0, scale=1.0)
    erig(b::Basis, i::Int, j::Int, n::Int, m::Int; alpha=1.0, scale=1.0)

Electron repulsion integral with Gaussian repulsion scale*exp(-α*r^2).

For erig4 `i` and `j` are indices for particale 1 and `n` and `m` for particale 2.
"""
function erig(b::Basis, i::Int, j::Int; alpha=1.0, scale=1.0)
    return scale * exp( -alpha * (b[i]-b[j])^2 )
end


function erig(b::Basis, i::Int, j::Int, n::Int, m::Int; alpha=1.0, scale=1.0)
    # TODO this function might not be type stable
    # Basis functions are orthogonal
    i != j && return zero(alpha)
    n != m && return zero(alpha)
    return erig(b, i, n; alpha=alpha, scale=scale)
end


function fock_matrix(b::Basis; alpha=1.0, scale=1.0)
    orbitals = initial_orbitals(b)
    return fock_matrix(b, orbitals)
end


function fock_matrix(b::Basis, orbitals::AbstractMatrix; alpha=1.0, scale=1.0)
    ∇ = derivative_matrix(b)
    g = metric_tensor(b)
    Eₖ = 0.5 * ∇' * g * ∇
    Vₙₑ = -2 .* scale .*  g * diagm( exp.( -alpha .* b.^2 ) )
    J = coulomb_matrix(b, orbitals)
    K = exchange_matrix(b, orbitals)
    h₁ = Eₖ +  Vₙₑ
    return h₁ + J - K
end


function coulomb_matrix(b::Basis, orbitals::AbstractMatrix)
    l = length(b)
    C = zeros(l, l)
    w = get_weight(b)

    # Two electrons in total
    ρ = orbitals[:,1] * orbitals[:,1]'
    for i in 1:l
        for j in 1:l
            C[i,j] = sum( n -> erig(b, i, j, n, n) * ρ[n,n] * w[n], 1:l)
            C[i,j] *= w[i]
        end
    end
    return C
end


function exchange_matrix(b::Basis, orbitals::AbstractMatrix)
    l = length(b)
    K = zeros(l,l)
    w = get_weight(b)

    # Two electrons in total
    ρ = orbitals[:,1] * orbitals[:,1]'
    for i in 1:l
        for j in 1:l
            for n in 1:l, m in 1:l
                K[i,j] += erig(b, i,n,j,m) * ρ[n,m]
            end
            # Add integral weigth for variable (2)
            K[i,j] *= w[i] * w[j]
        end
    end
    return K     
end


function bracket(
        b::Basis,
        psi1::AbstractVector,
        op::AbstractMatrix,
        psi2::AbstractVector
    )
    w = get_weight(b)
    return (conj.(psi1).*w)' * op * psi2
end

function bracket(b::Basis, psi1::AbstractVector, psi2::AbstractVector)
    w = get_weight(b)
    return sum( conj.(psi1) .* w .* psi2 )
end