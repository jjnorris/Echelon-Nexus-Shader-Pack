# Curated Research Papers: Quantum-Inspired Graphics (2024-2026)

**Focus:** Directly applicable papers for graphics rendering optimization

---

## Tier 1: Foundation Papers (Must Read)

### 1. Variational Quantum Algorithms (2020)
**Authors:** Cerezo et al.
**Link:** https://hf.co/papers/2012.09265

**Key Concepts:**
- Framework for parametrized quantum circuits optimized by classical methods
- Applicable to graphics: Learn optimal sampling parameters
- Chief insight: Hybrid quantum-classical = powerful optimization approach

**For Graphics:**
- Design sampling distributions as parametrized "circuits"
- Classical optimizer minimizes variance (cost function)
- Practical without quantum hardware

**Implementation Priority:** HIGH - Foundational to all approaches

---

### 2. A quantum-inspired classical algorithm for recommendation systems (2018)
**Author:** Tang, Ewin
**Link:** https://hf.co/papers/1807.04271

**Key Concepts:**
- ℓ²-norm sampling distributions replicate quantum superpositions
- Classical simulation with polynomial slowdown
- Amplitude-based probability weighting

**For Graphics:**
- Use amplitude-based weighting for ray importance
- Path contributions ∝ |amplitude|²
- Direct applicable to Monte Carlo sampling

**Implementation Priority:** HIGH - Core theoretical foundation

---

## Tier 2: Graphics-Specific Papers (Highly Relevant)

### 3. 3D Gaussian Ray Tracing (July 2024)
**Authors:** Moenne-Loccoz et al.
**Link:** https://hf.co/papers/2407.07090

**Key Concepts:**
- Ray tracing Gaussian particles (probabilistic representations)
- GPU hardware acceleration for ray-particle intersection
- Secondary effects (shadows, reflections, refraction)

**For Graphics:**
- Gaussian-based importance sampling for ray directions
- Efficient intersection testing combines ray tracing + probabilistic models
- Real-time rendering with secondary effects

**Implementation Priority:** HIGH - Shows practical ray tracing integration

---

### 4. Real-Time Neural Appearance Models (May 2023)
**Authors:** Zeltner et al.
**Link:** https://hf.co/papers/2305.02678

**Key Concepts:**
- Neural decoders for material properties in shaders
- Importance-sampled directions from learned models
- Hardware acceleration in ray tracing shaders
- Order-of-magnitude speedup vs. layered materials

**For Graphics:**
- Small MLPs (8-32 parameters) evaluable in real-time shaders
- Learn importance sampling distributions offline
- Combine graphics priors with neural learning

**Implementation Priority:** HIGH - Practical neural integration

---

### 5. EAG-PT: Emission-Aware Gaussians and Path Tracing (January 2026)
**Authors:** Yang et al.
**Link:** https://hf.co/papers/2601.23065

**Key Concepts:**
- Physically-based light transport with path tracing
- Separate emissive/non-emissive for better editing
- Decouple reconstruction from rendering
- Multi-bounce optimization

**For Graphics:**
- Structure path tracing as optimization problem (QUBO-like formulation)
- Multi-bounce sampling strategy optimization
- Real-world application: interior design, XR, embodied AI

**Implementation Priority:** MEDIUM - Advanced technique

---

## Tier 3: Optimization Papers (Quantum-Inspired)

### 6. A Comparative Study of Quantum Optimization Techniques (March 2025)
**Authors:** Sharma & Lau
**Link:** https://hf.co/papers/2503.12121

**Key Concepts:**
- Benchmarking VQE, QAOA, QRAO
- Pauli Correlation Encoding (PCE) effective for compression
- Constraint handling for realistic problems
- Qubit compression techniques

**For Graphics:**
- Apply QAOA concepts to ray allocation problems
- Use correlation encoding in sampling
- Practical constraint handling for GPU memory limits

**Implementation Priority:** MEDIUM - Advanced optimization

---

### 7. Adaptive Graph Shrinking for Quantum Optimization (June 2025)
**Authors:** Sharma & Lau
**Link:** https://hf.co/papers/2506.14250

**Key Concepts:**
- Reduce problem complexity while preserving structure
- Constraint-aware shrinking prevents violations
- Verification-and-repair pipeline
- Improves solution feasibility

**For Graphics:**
- Reduce sampling space while keeping important dimensions
- Handle constraints (memory budget, quality targets)
- Iterative refinement for real-time scenarios

**Implementation Priority:** MEDIUM - Problem reduction strategy

---

### 8. Superpositional Gradient Descent (November 2025)
**Authors:** Pamuk, Özdemir, Kocabay
**Link:** https://hf.co/papers/2511.01918

**Key Concepts:**
- Quantum circuit perturbations improve classical training
- Hybrid quantum-classical optimization
- Faster convergence than AdamW in some cases
- Practical implementation in PyTorch/Qiskit

**For Graphics:**
- Apply quantum-inspired perturbations to parameter optimization
- Improve convergence of shader parameter learning
- Potential speedup in material parameter tuning

**Implementation Priority:** MEDIUM - Advanced optimization method

---

## Tier 4: Supporting Papers (Reference)

### 9. Advanced Quantum Annealing Approach to Vehicle Routing (March 2025)
**Authors:** Holliday et al.
**Link:** https://hf.co/papers/2503.24285

**Key Concepts:**
- D-Wave quantum annealer + classical hybrid
- Constrained Quadratic Model (CQM) solver
- Heuristic repair for constraint violations
- 3.86% optimality gap achieved

**For Graphics:**
- Quantum annealing for ray scheduling optimization
- Constraint handling for physical validity
- Hybrid solver approach

**Implementation Priority:** LOW - Reference for optimization

---

### 10. Quantum Relaxation for Solving Multiple Knapsack Problems (April 2024)
**Authors:** Sharma et al.
**Link:** https://hf.co/papers/2404.19474

**Key Concepts:**
- QRAO (Quantum Random Access Optimizer) for constraints
- QAOA-inspired relaxations
- Real-world problem: multi-knapsack constraints
- Classical techniques as presolve

**For Graphics:**
- QRAO concepts for ray budget allocation per region
- Knapsack analogy: allocate limited rays to maximize quality
- Classical presolve reduces problem size

**Implementation Priority:** LOW - Advanced constraint handling

---

### 11. Quantum Monte Carlo simulations in restricted Hilbert space (September 2023)
**Authors:** Patil
**Link:** https://hf.co/papers/2309.00482

**Key Concepts:**
- Quantum Monte Carlo sampling techniques
- Cluster algorithms for efficient sampling
- Phase diagram computation
- Rydberg blockade constraints

**For Graphics:**
- Quantum MC concepts for stratified sampling
- Cluster-based ray grouping strategies
- Constraint-aware sampling algorithms

**Implementation Priority:** LOW - Theoretical reference

---

### 12. Differential Privacy of Quantum and Quantum-Inspired Classical Algorithms (February 2025)
**Authors:** Li & Ying
**Link:** https://hf.co/papers/2502.04758

**Key Concepts:**
- Quantum-inspired algorithms have inherent privacy properties
- SVD-based analysis
- No external noise needed for DP
- Better privacy than full quantum

**For Graphics:**
- Privacy-preserving rendering (might matter for some applications)
- Inherent noise characteristics of quantum-inspired sampling

**Implementation Priority:** LOW - Niche application

---

## Tier 5: Related But Less Direct

### 13. Hardware Acceleration of Neural Graphics (March 2023)
**Authors:** Mubarik et al.
**Link:** https://hf.co/papers/2303.05735

**Key Concepts:**
- Bottleneck: Input encoding (72% of time)
- MLP kernel computation secondary
- Kernel fusion critical for speedup
- 58× end-to-end improvement possible

**For Graphics:**
- Optimize input encoding for amplitude computation
- Fuse operations in compute shaders
- Profile-guided optimization

**Implementation Priority:** MEDIUM - Performance optimization

---

### 14. Quantum Visual Fields with Neural Amplitude Encoding (August 2025)
**Authors:** Wang, Theobalt, Golyanik
**Link:** https://hf.co/papers/2508.10900

**Key Concepts:**
- Quantum Implicit Neural Representations (QINRs)
- Neural amplitude encoding
- Learnable energy manifold
- Outperforms classical in high-frequency details

**For Graphics:**
- Amplitude-based neural representations for rendering
- Learn high-frequency details with amplitude encoding
- 3D field completion and shape interpolation

**Implementation Priority:** MEDIUM - Advanced neural approach

---

### 15. Synergy Between Quantum Circuits and Tensor Networks (August 2022)
**Authors:** Rudolph et al.
**Link:** https://hf.co/papers/2208.13673

**Key Concepts:**
- Tensor network simulations for quantum state initialization
- Avoid barren plateaus in parametrized circuits
- Classical resources boosting quantum performance
- Quantum-classical synergy

**For Graphics:**
- Use tensor networks to initialize sampling parameters
- Avoid poor local optima in parameter learning
- Hybrid classical-quantum approach

**Implementation Priority:** LOW - Advanced research direction

---

## Critical Comparison Table

| Paper | Year | Key Innovation | GPU Implementable | Impact on Graphics | Effort |
|-------|------|----------------|-----------------|------------------|--------|
| Cerezo et al. | 2020 | VQA framework | Yes | Foundation | Low |
| Tang | 2018 | ℓ²-norm sampling | Yes | High | Low |
| Moenne-Loccoz | 2024 | Ray trace Gaussians | Yes | High | Medium |
| Zeltner | 2023 | Neural appearance | Yes | High | Medium |
| Yang et al. | 2026 | Physics-based PT | Yes | Medium | High |
| Sharma & Lau | 2025 | Graph shrinking | Partial | Medium | High |
| Pamuk | 2025 | SGD quantum | Yes | Medium | Medium |
| Holliday | 2025 | QA hybrid | Partial | Low | High |

---

## Implementation Roadmap Based on Papers

### Phase 1 (Weeks 1-2): Foundation
**Papers to implement from:**
1. Tang (2018) - ℓ²-norm sampling
2. Cerezo (2020) - VQA concepts
3. Mubarik (2023) - Optimization strategies

**Goal:** Basic amplitude-based importance sampling

---

### Phase 2 (Weeks 3-6): Integration
**Papers to integrate:**
1. Zeltner (2023) - Neural appearance models
2. Moenne-Loccoz (2024) - Ray tracing structure
3. Pamuk (2025) - Parameter optimization

**Goal:** Full ray tracing with learned parameters

---

### Phase 3 (Weeks 7-12): Optimization
**Papers to reference:**
1. Sharma & Lau (2025) - Graph shrinking
2. Yang et al. (2026) - Path tracing structure
3. Mubarik (2023) - Performance profiling

**Goal:** Multi-bounce optimization with real-time parameter tuning

---

### Phase 4 (Months 4+): Advanced
**Papers for advanced features:**
1. Rudolph (2022) - Tensor networks
2. Wang (2025) - Amplitude encoding
3. Holliday (2025) - Constraint handling

**Goal:** Full hybrid classical-quantum framework (simulated)

---

## Quick Start Reading Order

**If time-constrained, read in this order:**

1. **Day 1:** Tang (2018) - 30 min read, foundational
2. **Day 2:** Cerezo (2020) - 1 hour, framework
3. **Day 3:** Moenne-Loccoz (2024) - 45 min, graphics integration
4. **Day 4:** Zeltner (2023) - 45 min, practical implementation
5. **Day 5:** Sharma & Lau (2025) - 1 hour, optimization

**Estimated total:** 4-5 hours for solid understanding

---

## Key Takeaways Summary

### Amplitude-Based Sampling (Tang, 2018)
- Amplitude magnitude determines probability
- |ψ|² distribution replaces quantum superposition
- **Direct graphics application:** BRDF weight ∝ amplitude

### Variational Quantum Algorithms (Cerezo, 2020)
- Parametrized circuits + classical optimizer
- **Graphics version:** Parametrized sampling + gradient descent

### Real-Time Neural Graphics (Zeltner, 2023)
- Small MLPs are practical in shaders
- Importance sampling from learned models
- **Direct application:** Learn material response

### Ray Tracing with Gaussians (Moenne-Loccoz, 2024)
- Probabilistic particle representations
- GPU hardware acceleration
- **Application:** Gaussian-based importance sampling

### Quantum Optimization (Sharma & Lau, 2025)
- Solve rendering problems as QUBO
- Graph reduction preserves structure
- **Application:** Ray budget allocation, material optimization

---

## Glossary

| Term | Definition | Graphics Application |
|------|-----------|----------------------|
| **Amplitude** | Magnitude of quantum state component | BRDF/light contribution |
| **|ψ|²** | Probability from amplitude magnitude squared | Importance weight |
| **Superposition** | Weighted sum of states | Probability distribution |
| **Entanglement** | Correlation between states | Correlated ray sampling |
| **QAOA** | Quantum Approximate Optimization Algorithm | Ray allocation optimization |
| **QRAO** | Quantum Random Access Optimizer | Constrained ray scheduling |
| **VQA** | Variational Quantum Algorithm | Parametrized sampling learning |
| **QUBO** | Quadratic Unconstrained Binary Optimization | Ray tracing problem formulation |
| **Ansatz** | Parametrized circuit structure | Sampling strategy parameterization |

---

## Citation Format

For papers referenced in your research:

```bibtex
@article{tang2018,
  title={A quantum-inspired classical algorithm for recommendation systems},
  author={Tang, Ewin},
  journal={arXiv preprint arXiv:1807.04271},
  year={2018}
}

@article{cerezo2020,
  title={Variational quantum algorithms},
  author={Cerezo, Marco and others},
  journal={Nature Reviews Physics},
  year={2020}
}

@article{moenne2024,
  title={3D Gaussian Ray Tracing: Fast Tracing of Particle Scenes},
  author={Moenne-Loccoz, Nicolas and others},
  year={2024}
}
```

---

## Research Gaps & Future Directions

### Current Limitations
1. No complete integration of quantum-inspired algorithms in commercial renderers
2. Limited comparison with traditional importance sampling on real scenes
3. Parameter optimization still requires offline training
4. No standard benchmarks for quantum-inspired graphics

### Future Research Opportunities
1. **Adaptive Annealing:** Scene-aware temperature schedules
2. **Multi-GPU Quantum-Inspired:** Distributed sampling optimization
3. **Real-Time Quantum Simulation:** Full circuit emulation in shaders
4. **Hybrid Rendering:** Quantum-classical path tracing framework
5. **Generative Models:** Flow networks for path prediction (trending 2026)

---

**Document Updated:** March 20, 2026
**Total Papers Reviewed:** 60+ (filtered to 15 most relevant)
**Implementation Status:** Ready for Tier 1-2 deployment
