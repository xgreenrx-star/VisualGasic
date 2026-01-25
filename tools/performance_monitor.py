#!/usr/bin/env python3
"""
VisualGasic Performance Monitor
Real-time performance monitoring and optimization suggestions
"""

import time
import psutil
import json
import threading
from datetime import datetime, timedelta
from collections import deque
import signal
import sys

class PerformanceMonitor:
    def __init__(self, sampling_interval=1.0):
        self.sampling_interval = sampling_interval
        self.running = False
        self.metrics_history = deque(maxlen=1000)
        self.performance_thresholds = {
            'cpu_percent': 80.0,
            'memory_percent': 85.0,
            'parse_time_ms': 100.0,
            'execution_time_ms': 50.0
        }
        self.optimization_suggestions = set()
        
    def start_monitoring(self):
        """Start real-time performance monitoring"""
        print("🔍 Starting VisualGasic Performance Monitor...")
        print(f"📊 Sampling every {self.sampling_interval}s")
        print("Press Ctrl+C to stop monitoring\n")
        
        self.running = True
        
        # Set up signal handler for graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        
        try:
            while self.running:
                metrics = self._collect_metrics()
                self.metrics_history.append(metrics)
                
                self._analyze_performance(metrics)
                self._print_live_stats(metrics)
                
                time.sleep(self.sampling_interval)
                
        except KeyboardInterrupt:
            pass
        finally:
            self._generate_final_report()
    
    def _signal_handler(self, signum, frame):
        """Handle Ctrl+C gracefully"""
        print("\n🛑 Stopping performance monitor...")
        self.running = False
    
    def _collect_metrics(self):
        """Collect system and application metrics"""
        timestamp = datetime.now()
        
        # System metrics
        cpu_percent = psutil.cpu_percent(interval=None)
        memory = psutil.virtual_memory()
        disk_io = psutil.disk_io_counters()
        
        # Simulated VisualGasic metrics
        # In real implementation, these would come from the profiler
        vg_metrics = self._simulate_visualgasic_metrics()
        
        metrics = {
            'timestamp': timestamp.isoformat(),
            'system': {
                'cpu_percent': cpu_percent,
                'memory_percent': memory.percent,
                'memory_used_mb': memory.used / (1024 * 1024),
                'memory_available_mb': memory.available / (1024 * 1024),
                'disk_read_mb': disk_io.read_bytes / (1024 * 1024) if disk_io else 0,
                'disk_write_mb': disk_io.write_bytes / (1024 * 1024) if disk_io else 0
            },
            'visualgasic': vg_metrics
        }
        
        return metrics
    
    def _simulate_visualgasic_metrics(self):
        """Simulate VisualGasic-specific metrics"""
        import random
        
        base_time = time.time()
        
        return {
            'parser': {
                'lines_parsed': random.randint(50, 200),
                'parse_time_ms': random.uniform(10, 150),
                'tokens_generated': random.randint(500, 2000),
                'parse_errors': random.randint(0, 3)
            },
            'execution': {
                'functions_called': random.randint(10, 50),
                'execution_time_ms': random.uniform(5, 80),
                'async_operations': random.randint(0, 10),
                'gpu_operations': random.randint(0, 5)
            },
            'memory': {
                'ast_nodes_active': random.randint(100, 1000),
                'memory_pool_usage_percent': random.uniform(20, 85),
                'string_interner_size': random.randint(500, 5000),
                'allocations_per_sec': random.randint(1000, 10000)
            },
            'performance': {
                'hot_paths_detected': random.randint(0, 5),
                'jit_compilations': random.randint(0, 2),
                'simd_operations': random.randint(5, 50),
                'cache_hit_rate': random.uniform(0.7, 0.95)
            }
        }
    
    def _analyze_performance(self, metrics):
        """Analyze metrics and generate optimization suggestions"""
        system = metrics['system']
        vg = metrics['visualgasic']
        
        # Check system thresholds
        if system['cpu_percent'] > self.performance_thresholds['cpu_percent']:
            self.optimization_suggestions.add("HIGH_CPU_USAGE")
        
        if system['memory_percent'] > self.performance_thresholds['memory_percent']:
            self.optimization_suggestions.add("HIGH_MEMORY_USAGE")
        
        # Check VisualGasic-specific thresholds
        if vg['parser']['parse_time_ms'] > self.performance_thresholds['parse_time_ms']:
            self.optimization_suggestions.add("SLOW_PARSING")
        
        if vg['execution']['execution_time_ms'] > self.performance_thresholds['execution_time_ms']:
            self.optimization_suggestions.add("SLOW_EXECUTION")
        
        # Check for positive indicators
        if vg['memory']['memory_pool_usage_percent'] > 80:
            self.optimization_suggestions.add("EXPAND_MEMORY_POOL")
        
        if vg['performance']['cache_hit_rate'] < 0.8:
            self.optimization_suggestions.add("IMPROVE_CACHING")
    
    def _print_live_stats(self, metrics):
        """Print live performance statistics"""
        # Clear screen and move cursor to top
        print("\033[H\033[J", end="")
        
        timestamp = datetime.fromisoformat(metrics['timestamp'])
        system = metrics['system']
        vg = metrics['visualgasic']
        
        print("🚀 VisualGasic Performance Monitor")
        print("=" * 60)
        print(f"⏰ {timestamp.strftime('%H:%M:%S')} | Sampling: {self.sampling_interval}s")
        print()
        
        # System metrics
        print("🖥️  SYSTEM METRICS")
        print(f"   CPU: {system['cpu_percent']:5.1f}% {self._get_status_indicator(system['cpu_percent'], 80)}")
        print(f"   Memory: {system['memory_percent']:5.1f}% ({system['memory_used_mb']:,.0f} MB) {self._get_status_indicator(system['memory_percent'], 85)}")
        print(f"   Disk I/O: R:{system['disk_read_mb']:6.1f} MB | W:{system['disk_write_mb']:6.1f} MB")
        print()
        
        # Parser metrics
        print("📝 PARSER PERFORMANCE")
        parse_lps = vg['parser']['lines_parsed'] / (vg['parser']['parse_time_ms'] / 1000) if vg['parser']['parse_time_ms'] > 0 else 0
        print(f"   Lines/sec: {parse_lps:8.0f} | Parse time: {vg['parser']['parse_time_ms']:5.1f}ms {self._get_status_indicator(vg['parser']['parse_time_ms'], 100, reverse=True)}")
        print(f"   Tokens: {vg['parser']['tokens_generated']:10,} | Errors: {vg['parser']['parse_errors']:3d}")
        print()
        
        # Execution metrics
        print("⚡ EXECUTION PERFORMANCE")
        print(f"   Functions/sec: {vg['execution']['functions_called']:6d} | Exec time: {vg['execution']['execution_time_ms']:5.1f}ms {self._get_status_indicator(vg['execution']['execution_time_ms'], 50, reverse=True)}")
        print(f"   Async ops: {vg['execution']['async_operations']:8d} | GPU ops: {vg['execution']['gpu_operations']:6d}")
        print()
        
        # Memory metrics
        print("💾 MEMORY PERFORMANCE")
        print(f"   Pool usage: {vg['memory']['memory_pool_usage_percent']:5.1f}% {self._get_status_indicator(vg['memory']['memory_pool_usage_percent'], 80)}")
        print(f"   AST nodes: {vg['memory']['ast_nodes_active']:8,} | Strings: {vg['memory']['string_interner_size']:7,}")
        print(f"   Alloc/sec: {vg['memory']['allocations_per_sec']:8,}")
        print()
        
        # Performance optimizations
        print("🔥 OPTIMIZATION STATUS")
        print(f"   Hot paths: {vg['performance']['hot_paths_detected']:6d} | JIT compiles: {vg['performance']['jit_compilations']:3d}")
        print(f"   SIMD ops: {vg['performance']['simd_operations']:7d} | Cache hit: {vg['performance']['cache_hit_rate']:5.1%}")
        print()
        
        # Active suggestions
        if self.optimization_suggestions:
            print("💡 OPTIMIZATION SUGGESTIONS")
            for suggestion in list(self.optimization_suggestions)[-5:]:  # Show last 5
                print(f"   {self._format_suggestion(suggestion)}")
            print()
        
        # Performance score
        score = self._calculate_performance_score(metrics)
        print(f"📊 PERFORMANCE SCORE: {score:.1f}/100 {self._get_performance_rating(score)}")
        
        print("=" * 60)
        print("Press Ctrl+C to stop monitoring and generate report")
    
    def _get_status_indicator(self, value, threshold, reverse=False):
        """Get status indicator emoji based on threshold"""
        if reverse:
            return "🟢" if value < threshold else "🟡" if value < threshold * 1.5 else "🔴"
        else:
            return "🟢" if value < threshold else "🟡" if value < threshold * 1.2 else "🔴"
    
    def _format_suggestion(self, suggestion):
        """Format optimization suggestions"""
        suggestions = {
            "HIGH_CPU_USAGE": "🔥 High CPU usage - Consider JIT compilation",
            "HIGH_MEMORY_USAGE": "💾 High memory usage - Expand memory pools",
            "SLOW_PARSING": "📝 Slow parsing - Enable AST caching",
            "SLOW_EXECUTION": "⚡ Slow execution - Profile hot paths",
            "EXPAND_MEMORY_POOL": "📦 Memory pool near capacity - Consider expansion",
            "IMPROVE_CACHING": "🗄️ Low cache hit rate - Optimize caching strategy"
        }
        return suggestions.get(suggestion, f"❓ {suggestion}")
    
    def _calculate_performance_score(self, metrics):
        """Calculate overall performance score"""
        system = metrics['system']
        vg = metrics['visualgasic']
        
        # System score (0-40 points)
        cpu_score = max(0, 20 - (system['cpu_percent'] - 50) * 0.5) if system['cpu_percent'] > 50 else 20
        memory_score = max(0, 20 - (system['memory_percent'] - 70) * 0.8) if system['memory_percent'] > 70 else 20
        system_score = cpu_score + memory_score
        
        # Parser score (0-30 points)
        parse_time = vg['parser']['parse_time_ms']
        parser_score = max(0, 30 - parse_time * 0.3) if parse_time > 10 else 30
        
        # Execution score (0-30 points)
        exec_time = vg['execution']['execution_time_ms']
        exec_score = max(0, 30 - exec_time * 0.6) if exec_time > 20 else 30
        
        total_score = min(100, system_score + parser_score + exec_score)
        return total_score
    
    def _get_performance_rating(self, score):
        """Get performance rating based on score"""
        if score >= 90:
            return "🎉 EXCELLENT"
        elif score >= 80:
            return "✅ GOOD"
        elif score >= 70:
            return "⚠️ FAIR"
        else:
            return "🔴 NEEDS WORK"
    
    def _generate_final_report(self):
        """Generate final performance report"""
        if not self.metrics_history:
            print("No metrics collected for report")
            return
        
        print("\n" + "=" * 60)
        print("📊 FINAL PERFORMANCE REPORT")
        print("=" * 60)
        
        # Calculate averages
        total_samples = len(self.metrics_history)
        
        avg_cpu = sum(m['system']['cpu_percent'] for m in self.metrics_history) / total_samples
        avg_memory = sum(m['system']['memory_percent'] for m in self.metrics_history) / total_samples
        avg_parse_time = sum(m['visualgasic']['parser']['parse_time_ms'] for m in self.metrics_history) / total_samples
        avg_exec_time = sum(m['visualgasic']['execution']['execution_time_ms'] for m in self.metrics_history) / total_samples
        
        print(f"Monitoring Duration: {total_samples * self.sampling_interval:.1f} seconds")
        print(f"Samples Collected: {total_samples}")
        print()
        
        print("AVERAGE PERFORMANCE:")
        print(f"  System CPU: {avg_cpu:.1f}%")
        print(f"  System Memory: {avg_memory:.1f}%")
        print(f"  Parse Time: {avg_parse_time:.1f}ms")
        print(f"  Execution Time: {avg_exec_time:.1f}ms")
        print()
        
        # Peak values
        peak_cpu = max(m['system']['cpu_percent'] for m in self.metrics_history)
        peak_memory = max(m['system']['memory_percent'] for m in self.metrics_history)
        max_parse_time = max(m['visualgasic']['parser']['parse_time_ms'] for m in self.metrics_history)
        max_exec_time = max(m['visualgasic']['execution']['execution_time_ms'] for m in self.metrics_history)
        
        print("PEAK PERFORMANCE:")
        print(f"  Peak CPU: {peak_cpu:.1f}%")
        print(f"  Peak Memory: {peak_memory:.1f}%")
        print(f"  Max Parse Time: {max_parse_time:.1f}ms")
        print(f"  Max Execution Time: {max_exec_time:.1f}ms")
        print()
        
        # Overall assessment
        final_score = sum(self._calculate_performance_score(m) for m in self.metrics_history) / total_samples
        print(f"OVERALL PERFORMANCE SCORE: {final_score:.1f}/100 {self._get_performance_rating(final_score)}")
        print()
        
        # Optimization recommendations
        if self.optimization_suggestions:
            print("RECOMMENDED OPTIMIZATIONS:")
            for suggestion in self.optimization_suggestions:
                print(f"  • {self._format_suggestion(suggestion)}")
        else:
            print("🎉 NO OPTIMIZATIONS NEEDED - Performance is excellent!")
        
        # Export data
        self._export_metrics_json()
        
        print("\n📄 Detailed metrics exported to performance_metrics.json")
        print("🔍 Use this data for further analysis and optimization")
    
    def _export_metrics_json(self):
        """Export metrics to JSON file"""
        export_data = {
            'monitoring_session': {
                'start_time': self.metrics_history[0]['timestamp'] if self.metrics_history else None,
                'end_time': self.metrics_history[-1]['timestamp'] if self.metrics_history else None,
                'duration_seconds': len(self.metrics_history) * self.sampling_interval,
                'sample_count': len(self.metrics_history)
            },
            'metrics': list(self.metrics_history),
            'optimization_suggestions': list(self.optimization_suggestions),
            'performance_thresholds': self.performance_thresholds
        }
        
        with open('performance_metrics.json', 'w') as f:
            json.dump(export_data, f, indent=2, default=str)

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='VisualGasic Performance Monitor')
    parser.add_argument('--interval', type=float, default=1.0, 
                       help='Sampling interval in seconds (default: 1.0)')
    parser.add_argument('--duration', type=int, default=0,
                       help='Monitoring duration in seconds (0 = infinite)')
    
    args = parser.parse_args()
    
    monitor = PerformanceMonitor(sampling_interval=args.interval)
    
    if args.duration > 0:
        # Run for specified duration
        print(f"🕐 Monitoring for {args.duration} seconds...")
        
        def stop_after_duration():
            time.sleep(args.duration)
            monitor.running = False
        
        timer = threading.Timer(args.duration, stop_after_duration)
        timer.start()
    
    monitor.start_monitoring()

if __name__ == "__main__":
    main()