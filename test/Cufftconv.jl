# Cufftconv.jl
# test FFT-based convolution and
# adjoint consistency for FFT convolution methods on very small case

using SPECTrecon: fft_conv!, fft_conv_adj!, plan_psf
using LinearAlgebra: dot


@testset "Cufftconv!" begin
    T = Float32
    nx = 12
    nz = 8
    px = 7
    pz = 7
    for i = 1:4
        img = randn(T, nx, nz)
        ker = rand(T, px, pz)
        ker_sym = ker .+ reverse(ker, dims=:)
        ker_sym /= sum(ker_sym)
        out = similar(img)
        Cuout = CuArray(out)
        Cuimg = CuArray(img)
        Cuker_sym = CuArray(ker_sym)

        plan = plan_psf( ; nx, nz, px, pz, T, nthread = 1)[1]
        fft_conv!(out, img, ker_sym, plan)
        Cuplan = CuPlanFFT( ; nx, nz, px, pz, T)
        Cufft_conv!(Cuout, Cuimg, Cuker_sym, Cuplan)
        @test isapprox(out, Array(Cuout))
    end
end


@testset "adjoint-Cufftconv!" begin
    nx = 20
    nz = 14
    px = 5
    pz = 5
    T = Float32
    for i = 1:4 # test with different kernels
        x = cu(randn(T, nx, nz))
        out_x = similar(x)
        y = cu(randn(T, nx, nz))
        out_y = similar(y)
        ker = cu(rand(T, px, pz))
        ker = ker .+ reverse(reverse(ker, dims=1), dims=2)
        ker /= sum(ker)
        plan = CuPlanFFT( ; nx, nz, px, pz, T)
        Cufft_conv!(out_x, x, ker, plan)
        Cufft_conv_adj!(out_y, y, ker, plan)

        @test dot(Array(out_x), Array(y)) ≈ dot(Array(out_y), Array(x))
    end
end
