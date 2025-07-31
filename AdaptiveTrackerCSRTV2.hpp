//------------------ AdaptiveTrackerCSRTV2.hpp -----------------//

/**
 * 自适应TrackerCSRTV2包装器
 * 
 * 解决CSRT参数无法运行时修改的问题，提供智能的参数自适应机制。
 * 当检测到目标大小显著变化时，自动重新初始化跟踪器。
 * 
 * 特性:
 * - 目标尺寸自适应
 * - 参数热更新
 * - PSR质量监控
 * - 智能重初始化
 * 
 * 作者: Cascade AI Assistant
 * 日期: 2025-07-24
 */

#ifndef ADAPTIVE_TRACKER_CSRTV2_HPP
#define ADAPTIVE_TRACKER_CSRTV2_HPP

#include <opencv2/opencv.hpp>
#include <opencv2/tracking.hpp>
#include <memory>
#include <deque>

class AdaptiveTrackerCSRTV2 {
public:
    struct AdaptiveParams {
        // 基础CSRT参数
        cv::tracking::TrackerCSRT::Params csrt_params;
        
        // 自适应参数
        float size_change_threshold = 0.3f;     // 尺寸变化阈值（30%）
        float psr_reinit_threshold = 0.02f;     // PSR过低时重初始化阈值
        int consecutive_low_psr_limit = 5;      // 连续低PSR帧数限制
        int reinit_cooldown_frames = 10;        // 重初始化冷却帧数
        bool enable_size_adaptation = true;     // 启用尺寸自适应
        bool enable_psr_monitoring = true;      // 启用PSR监控
        
        // 参数自适应策略
        bool auto_adjust_template_size = true;  // 自动调整模板大小
        bool auto_adjust_psr_threshold = true;  // 自动调整PSR阈值
        
        AdaptiveParams() {
            // 设置默认CSRT参数
            csrt_params.use_hog = true;
            csrt_params.use_color_names = true;
            csrt_params.use_gray = true;
            csrt_params.use_rgb = false;
            csrt_params.use_channel_weights = true;
            csrt_params.use_segmentation = true;
            csrt_params.template_size = 200.0f;
            csrt_params.gsl_sigma = 1.0f;
            csrt_params.hog_orientations = 9.0f;
            csrt_params.hog_clip = 0.2f;
            csrt_params.padding = 3.0f;
            csrt_params.filter_lr = 0.02f;
            csrt_params.weights_lr = 0.02f;
            csrt_params.num_hog_channels_used = 18;
            csrt_params.admm_iterations = 4;
            csrt_params.histogram_bins = 16;
            csrt_params.histogram_lr = 0.04f;
            csrt_params.background_ratio = 2;
            csrt_params.number_of_scales = 33;
            csrt_params.scale_sigma_factor = 0.250f;
            csrt_params.scale_model_max_area = 512.0f;
            csrt_params.scale_lr = 0.025f;
            csrt_params.scale_step = 1.020f;
            csrt_params.psr_threshold = 0.035f;
        }
    };
    
    struct TrackingState {
        bool is_initialized = false;
        bool is_tracking = false;
        cv::Rect2d current_bbox;
        cv::Rect2d initial_bbox;
        double current_psr = 0.0;
        double tracking_score = 0.0;
        int frame_count = 0;
        int consecutive_low_psr_count = 0;
        int frames_since_reinit = 0;
        
        // 历史信息
        std::deque<double> psr_history;
        std::deque<cv::Size2d> size_history;
        static const int HISTORY_SIZE = 10;
        
        void updateHistory(double psr, const cv::Size2d& size) {
            psr_history.push_back(psr);
            size_history.push_back(size);
            
            if (psr_history.size() > HISTORY_SIZE) {
                psr_history.pop_front();
            }
            if (size_history.size() > HISTORY_SIZE) {
                size_history.pop_front();
            }
        }
        
        double getAveragePSR() const {
            if (psr_history.empty()) return 0.0;
            double sum = 0.0;
            for (double psr : psr_history) {
                sum += psr;
            }
            return sum / psr_history.size();
        }
        
        cv::Size2d getAverageSize() const {
            if (size_history.empty()) return cv::Size2d(0, 0);
            double w = 0.0, h = 0.0;
            for (const auto& size : size_history) {
                w += size.width;
                h += size.height;
            }
            return cv::Size2d(w / size_history.size(), h / size_history.size());
        }
    };

private:
    cv::Ptr<cv::tracking::TrackerCSRTV2> tracker_;
    AdaptiveParams params_;
    TrackingState state_;
    cv::Mat last_frame_;
    
public:
    AdaptiveTrackerCSRTV2(const AdaptiveParams& params = AdaptiveParams()) 
        : params_(params) {}
    
    /**
     * 初始化跟踪器
     */
    bool init(const cv::Mat& image, const cv::Rect2d& bbox) {
        // 根据目标大小自适应调整模板尺寸
        if (params_.auto_adjust_template_size) {
            adaptTemplateSize(bbox);
        }
        
        // 创建TrackerCSRTV2实例
        tracker_ = cv::tracking::TrackerCSRTV2::create(params_.csrt_params);
        if (!tracker_) {
            return false;
        }
        
        // 初始化跟踪器
        cv::Rect rect(static_cast<int>(bbox.x), static_cast<int>(bbox.y),
                      static_cast<int>(bbox.width), static_cast<int>(bbox.height));
        
        bool success = tracker_->init(image, rect);
        if (success) {
            state_.is_initialized = true;
            state_.is_tracking = true;
            state_.current_bbox = bbox;
            state_.initial_bbox = bbox;
            state_.frame_count = 0;
            state_.consecutive_low_psr_count = 0;
            state_.frames_since_reinit = 0;
            last_frame_ = image.clone();
        }
        
        return success;
    }
    
    /**
     * 更新跟踪器（带自适应重初始化）
     */
    bool update(const cv::Mat& image, cv::Rect2d& bbox) {
        if (!state_.is_initialized || !tracker_) {
            return false;
        }
        
        state_.frame_count++;
        state_.frames_since_reinit++;
        
        // 执行跟踪更新
        cv::Rect rect;
        bool success = tracker_->update(image, rect);
        
        if (success) {
            bbox = cv::Rect2d(rect.x, rect.y, rect.width, rect.height);
            state_.current_bbox = bbox;
            
            // 获取跟踪质量信息
            state_.current_psr = tracker_->getRawPSR();
            state_.tracking_score = tracker_->getTrackingScore();
            
            // 更新历史信息
            state_.updateHistory(state_.current_psr, 
                               cv::Size2d(bbox.width, bbox.height));
            
            // 检查是否需要重新初始化
            if (shouldReinitialize(bbox)) {
                return reinitialize(image, bbox);
            }
            
            // 更新PSR计数
            if (state_.current_psr < params_.psr_reinit_threshold) {
                state_.consecutive_low_psr_count++;
            } else {
                state_.consecutive_low_psr_count = 0;
            }
        }
        
        last_frame_ = image.clone();
        return success;
    }
    
    /**
     * 动态更新参数（智能重初始化）
     */
    bool updateParams(const AdaptiveParams& new_params) {
        // 检查关键参数是否改变
        bool need_reinit = false;
        
        if (std::abs(new_params.csrt_params.template_size - params_.csrt_params.template_size) > 1e-6 ||
            new_params.csrt_params.number_of_scales != params_.csrt_params.number_of_scales ||
            std::abs(new_params.csrt_params.scale_model_max_area - params_.csrt_params.scale_model_max_area) > 1e-6) {
            need_reinit = true;
        }
        
        params_ = new_params;
        
        // 如果需要重初始化且当前正在跟踪
        if (need_reinit && state_.is_tracking && !last_frame_.empty()) {
            return reinitialize(last_frame_, state_.current_bbox);
        }
        
        return true;
    }
    
    /**
     * 获取当前跟踪状态
     */
    const TrackingState& getState() const {
        return state_;
    }
    
    /**
     * 获取跟踪质量分数
     */
    double getTrackingScore() const {
        return tracker_ ? tracker_->getTrackingScore() : 0.0;
    }
    
    /**
     * 获取原始PSR值
     */
    double getRawPSR() const {
        return tracker_ ? tracker_->getRawPSR() : 0.0;
    }
    
    /**
     * 检查目标是否丢失
     */
    bool isTargetLost() const {
        return tracker_ ? tracker_->isTargetLost() : true;
    }
    
    /**
     * 获取详细跟踪统计
     */
    cv::tracking::TrackerCSRTV2::TrackingStats getTrackingStats() const {
        if (tracker_) {
            return tracker_->getTrackingStats();
        }
        return cv::tracking::TrackerCSRTV2::TrackingStats();
    }

private:
    /**
     * 根据目标大小自适应调整模板尺寸
     */
    void adaptTemplateSize(const cv::Rect2d& bbox) {
        double target_area = bbox.width * bbox.height;
        
        // 根据目标面积调整模板大小
        if (target_area < 10000) {          // 小目标 (< 100x100)
            params_.csrt_params.template_size = 150.0f;
        } else if (target_area < 40000) {   // 中等目标 (< 200x200)
            params_.csrt_params.template_size = 200.0f;
        } else {                            // 大目标
            params_.csrt_params.template_size = 250.0f;
        }
        
        // 根据目标大小调整其他参数
        if (target_area > 50000) {
            params_.csrt_params.number_of_scales = 25;  // 大目标减少尺度数
        } else {
            params_.csrt_params.number_of_scales = 33;  // 小目标保持更多尺度
        }
    }
    
    /**
     * 检查是否需要重新初始化
     */
    bool shouldReinitialize(const cv::Rect2d& current_bbox) {
        // 冷却期检查
        if (state_.frames_since_reinit < params_.reinit_cooldown_frames) {
            return false;
        }
        
        // PSR过低检查
        if (params_.enable_psr_monitoring && 
            state_.consecutive_low_psr_count >= params_.consecutive_low_psr_limit) {
            return true;
        }
        
        // 尺寸变化检查
        if (params_.enable_size_adaptation && !state_.size_history.empty()) {
            cv::Size2d avg_size = state_.getAverageSize();
            double size_change = std::abs(current_bbox.area() - avg_size.area()) / avg_size.area();
            
            if (size_change > params_.size_change_threshold) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * 重新初始化跟踪器
     */
    bool reinitialize(const cv::Mat& image, const cv::Rect2d& bbox) {
        // 根据新的目标大小调整参数
        if (params_.auto_adjust_template_size) {
            adaptTemplateSize(bbox);
        }
        
        // 创建新的跟踪器实例
        tracker_ = cv::tracking::TrackerCSRTV2::create(params_.csrt_params);
        if (!tracker_) {
            return false;
        }
        
        // 重新初始化
        cv::Rect rect(static_cast<int>(bbox.x), static_cast<int>(bbox.y),
                      static_cast<int>(bbox.width), static_cast<int>(bbox.height));
        
        bool success = tracker_->init(image, rect);
        if (success) {
            state_.consecutive_low_psr_count = 0;
            state_.frames_since_reinit = 0;
            // 保留历史信息，但重置计数器
        }
        
        return success;
    }
};

#endif // ADAPTIVE_TRACKER_CSRTV2_HPP
