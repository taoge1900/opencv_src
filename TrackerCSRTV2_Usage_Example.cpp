//------------------ TrackerCSRTV2_Usage_Example.cpp -----------------//

/**
 * TrackerCSRTV2 使用示例
 * 
 * 此文件展示了如何在你的项目中使用新的TrackerCSRTV2类来获取跟踪质量分数。
 * 这是一个完整的示例，展示了从初始化到获取PSR值的完整流程。
 * 
 * 编译要求:
 * - 使用修改后的OpenCV 4.10.0 (包含TrackerCSRTV2)
 * - 链接opencv_tracking模块
 * 
 * 作者: Cascade AI Assistant
 * 日期: 2025-07-24
 */

#include <opencv2/opencv.hpp>
#include <opencv2/tracking.hpp>
#include <iostream>
#include <iomanip>

class TrackerCSRTV2Example {
private:
    cv::Ptr<cv::tracking::TrackerCSRTV2> tracker_;
    cv::VideoCapture cap_;
    cv::Rect2d bbox_;
    bool initialized_;
    
public:
    TrackerCSRTV2Example() : initialized_(false) {}
    
    /**
     * 初始化跟踪器
     */
    bool initializeTracker(const std::string& video_path, const cv::Rect2d& initial_bbox) {
        // 打开视频
        cap_.open(video_path);
        if (!cap_.isOpened()) {
            std::cerr << "错误: 无法打开视频文件: " << video_path << std::endl;
            return false;
        }
        
        // 读取第一帧
        cv::Mat frame;
        cap_ >> frame;
        if (frame.empty()) {
            std::cerr << "错误: 无法读取视频帧" << std::endl;
            return false;
        }
        
        // 配置CSRT参数
        cv::tracking::TrackerCSRT::Params params;
        params.use_hog = true;
        params.use_color_names = true;
        params.use_gray = true;
        params.use_rgb = false;
        params.use_channel_weights = true;
        params.use_segmentation = true;
        
        // 调整PSR阈值以获得更敏感的质量检测
        params.psr_threshold = 0.025f;  // 默认0.035f，降低以获得更早的质量警告
        
        params.template_size = 200.0f;
        params.gsl_sigma = 1.0f;
        params.hog_orientations = 9.0f;
        params.hog_clip = 0.2f;
        params.padding = 3.0f;
        params.filter_lr = 0.02f;
        params.weights_lr = 0.02f;
        params.num_hog_channels_used = 18;
        params.admm_iterations = 4;
        params.histogram_bins = 16;
        params.histogram_lr = 0.04f;
        params.background_ratio = 2;
        params.number_of_scales = 33;
        params.scale_sigma_factor = 0.250f;
        params.scale_model_max_area = 512.0f;
        params.scale_lr = 0.025f;
        params.scale_step = 1.020f;
        
        // 创建TrackerCSRTV2实例
        tracker_ = cv::tracking::TrackerCSRTV2::create(params);
        if (!tracker_) {
            std::cerr << "错误: 无法创建TrackerCSRTV2实例" << std::endl;
            return false;
        }
        
        // 初始化跟踪器
        bbox_ = initial_bbox;
        cv::Rect rect(static_cast<int>(bbox_.x), static_cast<int>(bbox_.y),
                      static_cast<int>(bbox_.width), static_cast<int>(bbox_.height));
        
        tracker_->init(frame, rect);
        initialized_ = true;
        
        std::cout << "✅ TrackerCSRTV2 初始化成功" << std::endl;
        std::cout << "   初始边界框: (" << bbox_.x << ", " << bbox_.y 
                  << ", " << bbox_.width << ", " << bbox_.height << ")" << std::endl;
        std::cout << "   PSR阈值: " << params.psr_threshold << std::endl;
        
        return true;
    }
    
    /**
     * 处理单帧并获取跟踪质量信息
     */
    bool processFrame(cv::Mat& frame, bool show_info = true) {
        if (!initialized_ || !tracker_) {
            std::cerr << "错误: 跟踪器未初始化" << std::endl;
            return false;
        }
        
        // 更新跟踪器
        cv::Rect rect;
        bool success = tracker_->update(frame, rect);
        
        if (success) {
            bbox_ = cv::Rect2d(rect.x, rect.y, rect.width, rect.height);
        }
        
        // 获取跟踪质量信息
        double tracking_score = tracker_->getTrackingScore();
        double raw_psr = tracker_->getRawPSR();
        bool target_lost = tracker_->isTargetLost();
        
        // 获取详细统计信息
        auto stats = tracker_->getTrackingStats();
        
        if (show_info) {
            printTrackingInfo(success, tracking_score, raw_psr, target_lost, stats);
        }
        
        // 在图像上绘制跟踪结果
        drawTrackingResult(frame, success, tracking_score, target_lost);
        
        return success;
    }
    
    /**
     * 运行完整的跟踪演示
     */
    void runDemo() {
        if (!initialized_) {
            std::cerr << "错误: 跟踪器未初始化" << std::endl;
            return;
        }
        
        cv::Mat frame;
        int frame_count = 0;
        
        std::cout << "\n🎬 开始跟踪演示..." << std::endl;
        std::cout << "按 'q' 退出，按 's' 显示统计信息" << std::endl;
        
        while (true) {
            cap_ >> frame;
            if (frame.empty()) {
                std::cout << "📹 视频结束" << std::endl;
                break;
            }
            
            frame_count++;
            
            // 处理帧（每10帧显示一次详细信息）
            bool show_info = (frame_count % 10 == 0);
            bool success = processFrame(frame, show_info);
            
            // 显示结果
            cv::imshow("TrackerCSRTV2 Demo", frame);
            
            char key = cv::waitKey(1) & 0xFF;
            if (key == 'q') {
                break;
            } else if (key == 's') {
                printDetailedStats();
            }
            
            // 如果跟踪失败太多次，可以考虑重新初始化
            if (!success && frame_count > 10) {
                auto stats = tracker_->getTrackingStats();
                if (stats.success_rate < 0.5) {
                    std::cout << "⚠️  跟踪成功率过低 (" << stats.success_rate 
                              << ")，建议重新初始化" << std::endl;
                }
            }
        }
        
        cv::destroyAllWindows();
        printFinalStats();
    }
    
private:
    /**
     * 打印跟踪信息
     */
    void printTrackingInfo(bool success, double tracking_score, double raw_psr, 
                          bool target_lost, const cv::tracking::TrackerCSRTV2::TrackingStats& stats) {
        std::cout << std::fixed << std::setprecision(4);
        
        if (success) {
            std::cout << "✅ 跟踪成功 | ";
        } else {
            std::cout << "❌ 跟踪失败 | ";
        }
        
        std::cout << "质量分数: " << tracking_score 
                  << " | 原始PSR: " << raw_psr;
        
        if (target_lost) {
            std::cout << " | 🎯 目标丢失";
        }
        
        std::cout << " | 成功率: " << (stats.success_rate * 100) << "%";
        std::cout << std::endl;
    }
    
    /**
     * 在图像上绘制跟踪结果
     */
    void drawTrackingResult(cv::Mat& frame, bool success, double tracking_score, bool target_lost) {
        if (success) {
            // 根据跟踪质量选择颜色
            cv::Scalar color;
            if (tracking_score > 0.7) {
                color = cv::Scalar(0, 255, 0);  // 绿色 - 高质量
            } else if (tracking_score > 0.4) {
                color = cv::Scalar(0, 255, 255);  // 黄色 - 中等质量
            } else {
                color = cv::Scalar(0, 0, 255);  // 红色 - 低质量
            }
            
            // 绘制边界框
            cv::rectangle(frame, bbox_, color, 2);
            
            // 显示质量分数
            std::string score_text = "Score: " + std::to_string(tracking_score).substr(0, 5);
            cv::putText(frame, score_text, 
                       cv::Point(bbox_.x, bbox_.y - 10), 
                       cv::FONT_HERSHEY_SIMPLEX, 0.6, color, 2);
            
            // 显示目标状态
            if (target_lost) {
                cv::putText(frame, "TARGET LOST", 
                           cv::Point(bbox_.x, bbox_.y + bbox_.height + 25), 
                           cv::FONT_HERSHEY_SIMPLEX, 0.7, cv::Scalar(0, 0, 255), 2);
            }
        } else {
            // 跟踪失败时显示红色X
            cv::putText(frame, "TRACKING FAILED", 
                       cv::Point(50, 50), 
                       cv::FONT_HERSHEY_SIMPLEX, 1.0, cv::Scalar(0, 0, 255), 2);
        }
    }
    
    /**
     * 打印详细统计信息
     */
    void printDetailedStats() {
        if (!tracker_) return;
        
        auto stats = tracker_->getTrackingStats();
        
        std::cout << "\n📊 详细统计信息:" << std::endl;
        std::cout << "   当前PSR: " << stats.current_psr << std::endl;
        std::cout << "   平均PSR: " << stats.avg_psr << std::endl;
        std::cout << "   最小PSR: " << stats.min_psr << std::endl;
        std::cout << "   最大PSR: " << stats.max_psr << std::endl;
        std::cout << "   成功帧数: " << stats.successful_frames << std::endl;
        std::cout << "   总帧数: " << stats.total_frames << std::endl;
        std::cout << "   成功率: " << (stats.success_rate * 100) << "%" << std::endl;
        std::cout << std::endl;
    }
    
    /**
     * 打印最终统计信息
     */
    void printFinalStats() {
        std::cout << "\n🏁 跟踪完成 - 最终统计:" << std::endl;
        printDetailedStats();
    }
};

/**
 * 主函数 - 演示如何使用TrackerCSRTV2
 */
int main(int argc, char* argv[]) {
    std::cout << "🚀 TrackerCSRTV2 使用示例" << std::endl;
    std::cout << "=========================" << std::endl;
    
    // 检查参数
    if (argc < 2) {
        std::cout << "使用方法: " << argv[0] << " <video_path> [x] [y] [width] [height]" << std::endl;
        std::cout << "示例: " << argv[0] << " test_video.mp4 100 100 200 150" << std::endl;
        return -1;
    }
    
    std::string video_path = argv[1];
    
    // 默认边界框或从命令行参数获取
    cv::Rect2d initial_bbox;
    if (argc >= 6) {
        initial_bbox = cv::Rect2d(
            std::stod(argv[2]),  // x
            std::stod(argv[3]),  // y
            std::stod(argv[4]),  // width
            std::stod(argv[5])   // height
        );
    } else {
        // 使用默认边界框
        initial_bbox = cv::Rect2d(100, 100, 200, 150);
        std::cout << "使用默认边界框: (100, 100, 200, 150)" << std::endl;
    }
    
    // 创建并运行示例
    TrackerCSRTV2Example example;
    
    if (!example.initializeTracker(video_path, initial_bbox)) {
        std::cerr << "初始化失败" << std::endl;
        return -1;
    }
    
    example.runDemo();
    
    std::cout << "👋 演示结束" << std::endl;
    return 0;
}

/**
 * 编译命令示例:
 * 
 * g++ -std=c++11 TrackerCSRTV2_Usage_Example.cpp \
 *     -I/path/to/opencv/include \
 *     -L/path/to/opencv/lib \
 *     -lopencv_core -lopencv_imgproc -lopencv_imgcodecs \
 *     -lopencv_videoio -lopencv_highgui -lopencv_tracking \
 *     -o tracker_demo
 * 
 * 或者使用CMake:
 * 
 * find_package(OpenCV REQUIRED)
 * add_executable(tracker_demo TrackerCSRTV2_Usage_Example.cpp)
 * target_link_libraries(tracker_demo ${OpenCV_LIBS})
 */
