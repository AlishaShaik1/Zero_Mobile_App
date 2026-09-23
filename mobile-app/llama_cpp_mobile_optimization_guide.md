# LLAMA.CPP MAXIMUM PERFORMANCE OPTIMIZATION GUIDE FOR MOBILE/ANDROID
# Target: 100x-400x throughput improvement on budget phones

## =================================================================
## PART 1: COMPILATION FLAGS FOR MAXIMUM CPU UTILIZATION
## =================================================================

### Android/Termux Build Commands

```bash
# 1. Clone llama.cpp
cd ~
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# 2. Install dependencies
pkg update
pkg install cmake clang git

# 3. Configure with MAXIMUM optimization flags
# For ARM64 with NEON, FP16, DOTPROD support
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="-O3 -mcpu=native -mtune=native -ffast-math -funroll-loops -fomit-frame-pointer" \
  -DCMAKE_CXX_FLAGS="-O3 -mcpu=native -mtune=native -ffast-math -funroll-loops -fomit-frame-pointer" \
  -DGGML_NATIVE=ON \
  -DGGML_OPENMP=ON \
  -DGGML_CPU_ARM_ARCH=native \
  -DGGML_CPU_AARCH64=ON

# 4. Build with all cores
cmake --build build --config Release -j$(nproc)

# Alternative: Use make with explicit flags (older method)
make -j$(nproc) \
  CFLAGS="-O3 -mcpu=native -mtune=native -ffast-math -funroll-loops" \
  CXXFLAGS="-O3 -mcpu=native -mtune=native -ffast-math -funroll-loops"
```

### Critical Compiler Flags Explained:
- `-O3`: Maximum optimization level
- `-mcpu=native`: Use all CPU features of target device
- `-mtune=native`: Tune for specific CPU architecture
- `-ffast-math`: Allow aggressive floating-point optimizations
- `-funroll-loops`: Unroll loops for better performance
- `-fomit-frame-pointer`: Free up a register
- `-DGGML_OPENMP=ON`: Enable OpenMP for multi-threading

## =================================================================
## PART 2: THREADING & CPU AFFINITY (P-CORES vs E-CORES)
## =================================================================

### Understanding big.LITTLE Architecture
- P-cores (Performance): High frequency, high power
- E-cores (Efficiency): Low frequency, low power
- On Android, you MUST pin to P-cores for maximum throughput

### Method 1: Using taskset (Requires Root)
```bash
# Find your P-cores (usually the higher-numbered cores)
# Example: 4 P-cores (4-7) + 4 E-cores (0-3)

# Pin llama.cpp to P-cores only
su -c "taskset -c 4-7 ./llama-cli -m model.gguf -p 'Hello' -t 4"

# Or use all cores but prioritize P-cores
su -c "taskset -c 0-7 ./llama-cli -m model.gguf -p 'Hello' -t 8"
```

### Method 2: Using -t flag (Thread Count)
```bash
# Set threads to number of P-cores for consistent performance
./llama-cli -m model.gguf -p "Hello" -t 4

# For batch processing, use all cores
./llama-cli -m model.gguf -p "Hello" -t $(nproc)
```

### Method 3: OMP_NUM_THREADS Environment Variable
```bash
export OMP_NUM_THREADS=4  # Set to P-core count
export OMP_PROC_BIND=close
export OMP_PLACES=cores
./llama-cli -m model.gguf -p "Hello"
```

## =================================================================
## PART 3: BYPASSING THERMAL THROTTLING (REQUIRES ROOT)
## =================================================================

### WARNING: THIS CAN DAMAGE YOUR DEVICE. USE WITH EXTREME CAUTION.

### Method 1: Magisk Module (Recommended)
Install "Kill-Needless-Thermal-Limits" or "Universal-Thermal-Controller"

### Method 2: Manual sysfs Commands
```bash
# Requires root access
su

# 1. Set CPU governor to performance
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > "$cpu"
done

# 2. Disable thermal zones
for zone in /sys/class/thermal/thermal_zone*/; do
    if [ -f "$zone/mode" ]; then
        echo disabled > "$zone/mode"
    fi
    if [ -f "$zone/trip_point_0_temp" ]; then
        echo 125000 > "$zone/trip_point_0_temp"  # 125°C
    fi
done

# 3. Stop thermal daemon
stop thermald 2>/dev/null
stop thermal-engine 2>/dev/null

# 4. Set GPU to performance (Qualcomm)
if [ -f /sys/class/kgsl/kgsl-3d0/devfreq/governor ]; then
    echo performance > /sys/class/kgsl/kgsl-3d0/devfreq/governor
fi

# 5. Lock CPU frequencies to max
for policy in /sys/devices/system/cpu/cpufreq/policy*/; do
    max_freq=$(cat "$policy/cpuinfo_max_freq")
    echo $max_freq > "$policy/scaling_min_freq"
    echo $max_freq > "$policy/scaling_max_freq"
done
```

### Method 3: Using Kernel Adiutor App (Root)
1. Install Kernel Adiutor from F-Droid
2. Set CPU Governor: Performance
3. Disable Thermal Throttling
4. Set all cores to maximum frequency

## =================================================================
## PART 4: MEMORY LOCKING (mlock) & NO-MMAP
## =================================================================

### Why mlock is Critical on Mobile
- Prevents Android's Low Memory Killer (LMK) from killing your process
- Keeps model weights in RAM (no swapping to zRAM)
- Reduces page faults during inference

### Usage:
```bash
# COMBINE --mlock and --no-mmap for maximum stability
./llama-cli \
  -m model.gguf \
  --mlock \
  --no-mmap \
  -p "Hello"

# For server mode
./llama-server \
  -m model.gguf \
  --mlock \
  --no-mmap \
  --host 127.0.0.1 \
  --port 8080
```

### Android-Specific Memory Workarounds:
```bash
# 1. Increase process priority (requires root)
su -c "renice -n -20 -p $(pidof llama-cli)"

# 2. Lock process in memory (requires root)
su -c "echo -17 > /proc/$(pidof llama-cli)/oom_score_adj"

# 3. Disable swap (temporary)
su -c "swapoff -a"

# 4. Clear caches before running
su -c "echo 3 > /proc/sys/vm/drop_caches"
```

## =================================================================
## PART 5: SPECULATIVE DECODING FOR 2x-10x SPEEDUP
## =================================================================

### N-gram Cache (Best for Code/Template Generation)
```bash
# For llama.cpp server
./llama-server \
  -m model.gguf \
  --spec-type ngram-cache \
  --spec-ngram-size 5 \
  --spec-ngram-count 12 \
  --spec-ngram-recycle 1024

# For CLI
./llama-cli \
  -m model.gguf \
  --spec-type ngram-cache \
  -p "Write a function to"
```

### N-gram Mod (Better for mixed content)
```bash
./llama-server \
  -m model.gguf \
  --spec-type ngram-mod \
  --spec-ngram-mod-n-match 24 \
  --spec-ngram-mod-n-min 48 \
  --spec-ngram-mod-n-max 64 \
  --spec-draft-n-max 32
```

### Expected Speedups:
- Repetitive code: 2x-10x faster
- General text: 1.2x-2x faster
- Random/creative text: Minimal improvement

## =================================================================
## PART 6: KV CACHE OPTIMIZATION (Fixes Long-Generation Slowdown)
## =================================================================

### The Problem:
As context grows, KV cache memory bandwidth becomes the bottleneck.
Speed drops from ~5 tok/s to ~1 tok/s on long generations.

### Solutions:

#### 1. Quantize KV Cache
```bash
# Use Q4_0 for KV cache (4-bit) - MASSIVE memory savings
./llama-cli \
  -m model.gguf \
  --cache-type-k q4_0 \
  --cache-type-v q4_0 \
  --flash-attn \
  -p "Hello"

# Or Q8_0 for better quality
./llama-cli \
  -m model.gguf \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --flash-attn \
  -p "Hello"
```

#### 2. Reduce Context Window
```bash
# Limit context to prevent slowdown
./llama-cli -m model.gguf -c 2048 -p "Hello"
# Instead of default 4096 or higher
```

#### 3. Flash Attention (CRITICAL)
```bash
# ALWAYS enable flash attention on mobile
./llama-cli -m model.gguf --flash-attn -p "Hello"
```

## =================================================================
## PART 7: COMPLETE OPTIMIZED COMMAND FOR MOBILE
## =================================================================

```bash
#!/bin/bash
# save as: run_llama_max_performance.sh

# 1. Apply thermal bypass (requires root)
if [ "$(id -u)" -eq 0 ]; then
    # Set performance governor
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance > "$cpu" 2>/dev/null
    done
    
    # Disable thermal zones
    for zone in /sys/class/thermal/thermal_zone*/mode; do
        echo disabled > "$zone" 2>/dev/null
    done
    
    # Stop thermal services
    stop thermald 2>/dev/null
    stop thermal-engine 2>/dev/null
fi

# 2. Set environment variables
export OMP_NUM_THREADS=4
export OMP_PROC_BIND=close
export OMP_PLACES=cores

# 3. Run llama.cpp with ALL optimizations
./llama-cli \
  -m model.gguf \
  -t 4 \
  -c 2048 \
  -b 512 \
  -ub 512 \
  -n 512 \
  --mlock \
  --no-mmap \
  --flash-attn \
  --cache-type-k q4_0 \
  --cache-type-v q4_0 \
  --spec-type ngram-cache \
  --spec-ngram-size 5 \
  --spec-ngram-count 12 \
  --temp 0.8 \
  -p "Your prompt here"
```

## =================================================================
## PART 8: MODEL SELECTION FOR MOBILE
## =================================================================

### Recommended Models for Budget Phones:
1. **Qwen2.5-0.5B** or **1.5B** - Ultra-fast, good for basic tasks
2. **Phi-3-mini (3.8B)** - Good balance
3. **Llama-3.2-1B** - Fast, decent quality
4. **DeepSeek-R1-Distill-Qwen-1.5B** - Good for reasoning

### Quantization Strategy:
- **Q4_K_M**: Best speed/quality ratio (RECOMMENDED)
- **Q5_K_M**: Slightly better quality, 20% slower
- **Q8_0**: Best quality, 2x slower than Q4
- **IQ2_XXS**: Extreme quantization, 3x faster, lower quality

## =================================================================
## PART 9: FLUTTER INTEGRATION FOR CODE GENERATION
## =================================================================

### Using llama.cpp via FFI in Flutter:

```dart
// pubspec.yaml dependencies:
// ffi: ^2.1.0

import 'dart:ffi';
import 'dart:io';

class LlamaCppBindings {
  static final DynamicLibrary _lib = Platform.isAndroid
      ? DynamicLibrary.open('libllama.so')
      : DynamicLibrary.process();

  // Bind to llama.cpp C API
  // ... implementation
}

// Optimization wrapper for Flutter
class LlamaOptimizer {
  static Future<String> generateWithMaxPerformance(
    String modelPath,
    String prompt, {
    int maxTokens = 512,
    int threads = 4,
    int contextSize = 2048,
  }) async {
    // Run in isolate to avoid blocking UI
    return await Isolate.run(() async {
      // Call optimized llama.cpp binary
      final result = await Process.run(
        './llama-cli',
        [
          '-m', modelPath,
          '-t', threads.toString(),
          '-c', contextSize.toString(),
          '-n', maxTokens.toString(),
          '--mlock',
          '--no-mmap',
          '--flash-attn',
          '--cache-type-k', 'q4_0',
          '--cache-type-v', 'q4_0',
          '--spec-type', 'ngram-cache',
          '-p', prompt,
        ],
      );
      return result.stdout as String;
    });
  }
}
```

## =================================================================
## PART 10: REALISTIC EXPECTATIONS
## =================================================================

### Budget Phone (4GB RAM, Octa-core):
- **Baseline**: 1-2 tokens/second (Q4_K_M, 1.5B model)
- **With optimizations**: 3-8 tokens/second
- **With speculative decoding**: 5-15 tokens/second (code only)

### Mid-range Phone (8GB RAM, Snapdragon 7-series):
- **Baseline**: 3-5 tokens/second (Q4_K_M, 3B model)
- **With optimizations**: 8-20 tokens/second
- **With speculative decoding**: 15-40 tokens/second (code only)

### Flagship Phone (12GB+ RAM, Snapdragon 8-series):
- **Baseline**: 8-15 tokens/second (Q4_K_M, 7B model)
- **With optimizations**: 20-50 tokens/second
- **With speculative decoding**: 40-100+ tokens/second (code only)

### Maximum Achievable (with ALL optimizations):
- **100x improvement**: ONLY possible with:
  1. Tiny models (0.5B-1B parameters)
  2. Highly repetitive code generation
  3. Speculative decoding with 90%+ acceptance
  4. Thermal bypass + all CPU cores at max
  5. Aggressive quantization (IQ2_XXS)

- **Realistic maximum**: 10x-30x improvement for most use cases

## =================================================================
## PART 11: MONITORING & SAFETY
## =================================================================

### Monitor Temperature:
```bash
# Check CPU temperature
for zone in /sys/class/thermal/thermal_zone*/temp; do
    echo "$zone: $(cat $zone)"
done

# Or use simple command
cat /sys/class/thermal/thermal_zone0/temp
```

### Safety Limits:
- **Stop if CPU > 85°C**
- **Stop if battery > 45°C**
- **Take breaks every 5-10 minutes**
- **Use active cooling if possible**

## =================================================================
## SUMMARY: QUICK START
## =================================================================

1. **Build**: Use `-O3 -mcpu=native` flags
2. **Threads**: Set `-t` to P-core count
3. **Thermal**: Bypass throttling (root required)
4. **Memory**: Use `--mlock --no-mmap`
5. **KV Cache**: Use `--cache-type-k q4_0 --cache-type-v q4_0`
6. **Flash Attention**: Always use `--flash-attn`
7. **Speculative**: Enable `--spec-type ngram-cache` for code
8. **Model**: Use Q4_K_M quantized, 1.5B-3B parameters
9. **Context**: Limit to `-c 2048` or less
10. **Safety**: Monitor temperature, don't overheat

### One-Liner Maximum Performance:
```bash
su -c "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > \$cpu; done; stop thermald 2>/dev/null; export OMP_NUM_THREADS=4; taskset -c 4-7 ./llama-cli -m model-Q4_K_M.gguf -t 4 -c 2048 -b 512 --mlock --no-mmap --flash-attn --cache-type-k q4_0 --cache-type-v q4_0 --spec-type ngram-cache -p 'Your prompt'"
```
