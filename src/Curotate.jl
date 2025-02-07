# Curotate.jl

using CUDA
export Cuimrotate!

"""
    Cuimrotate!(outarr, inarr, θ, plan)
GPU version of imrotate.
- `outarr`: output array
- `inarr`: input array
- `theta`: rotate angle (in rad)
- `plan`: rotate plan, see "Cuplan-rotate.jl"
Note: functions "Curot_f90!" and "Cupadzero!" are from "Cuhelper.jl"
"""
function Cuimrotate!(outarr::CuArray,
                     inarr::CuArray,
                     θ::Real,
                     plan::CuPlanRotate)
    if mod(θ, 2π) ≈ 0
        outarr .= inarr
        return outarr
    end
    m = mod(floor(Int, 0.5 + θ/(π/2)), 4)
    if θ ≈ m * (π/2)
        Curot_f90!(outarr, inarr, m)
    else
        mod_theta = θ - m * (π/2)
        sin_θ, cos_θ = sincos(mod_theta)
        Cupadzero!(plan.padded_src, inarr,
                    (plan.padsize, plan.padsize, plan.padsize, plan.padsize))
        Curot_f90!(plan.workmat1, plan.padded_src, m)
        copyto!(plan.padded_src, plan.workmat1)
        # multiply with the rotation matrix [cos(theta) sin(theta); -sin(theta) cos(theta)]
        broadcast!(*, plan.workmat1, plan.xaxis, cos_θ)
        broadcast!(*, plan.workmat2, plan.yaxis, sin_θ)
        broadcast!(+, plan.workmat1, plan.workmat1, plan.workmat2)
        broadcast!(*, plan.workmat2, plan.xaxis, sin_θ)
        broadcast!(*, plan.workmat3, plan.yaxis, cos_θ)
        broadcast!(-, plan.workmat2, plan.workmat3, plan.workmat2)
        broadcast!(+, plan.workmat1, plan.workmat1, plan.center)
        broadcast!(+, plan.workmat2, plan.workmat2, plan.center)
        # line 43 - 46 surely allocates some GPU memory
        allocated_idx = tuple.(plan.workmat1, plan.workmat2)
        tex = CuTexture(CuTextureArray(plan.padded_src);
                        interpolation = CUDA.LinearInterpolation(), # linear interpolation
                        address_mode = CUDA.ADDRESS_MODE_BORDER) # filling out-of-boundary values with zeros
        plan.query!(plan.workmat1, tex, allocated_idx) # give interpolated values
        copyto!(outarr, (@view plan.workmat1[plan.padsize .+ (1:plan.nx),
                                             plan.padsize .+ (1:plan.nx)]))
    end
    return outarr
end
