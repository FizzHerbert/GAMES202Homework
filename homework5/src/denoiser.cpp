#include "denoiser.h"

Denoiser::Denoiser() : m_useTemportal(false) {}

void Denoiser::Reprojection(const FrameInfo &frameInfo) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    Matrix4x4 preWorldToScreen =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 1];//只需要这个矩阵即可
    Matrix4x4 preWorldToCamera =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 2];
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Reproject
            float id = frameInfo.m_id(x, y);
            if (id >= 0.0f)//可能有背景
            {
                Matrix4x4 projectMatrix = preWorldToScreen * m_preFrameInfo.m_matrix[id] * Inverse(frameInfo.m_matrix[id]);
                Float3 projectPosition = projectMatrix(frameInfo.m_position(x, y), Float3::Point);
                int preX = projectPosition.x;
                int preY = projectPosition.y;
                if (preX >= 0 && preX < width && preY >= 0 && preY < height && (int)m_preFrameInfo.m_id(preX, preY) == (int)id)//在屏幕内且id相同
                {
                    m_valid(x, y) = true;
                    m_misc(x, y) = m_accColor(preX, preY);//为上一帧滤波后的信息
                    continue;
                }
            }
            m_valid(x, y) = false;
            m_misc(x, y) = Float3(0.f);
        }
    }
    std::swap(m_misc, m_accColor);
}

void Denoiser::TemporalAccumulation(const Buffer2D<Float3> &curFilteredColor) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    int kernelRadius = 3;
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Temporal clamp
            Float3 color = m_accColor(x, y);//上一帧的像素值
            Float3 curcolor = curFilteredColor(x, y);
            int neighborRadiance = 3;
            int neighbotArea = 0;
            // TODO: Exponential moving average
            float alpha = 1.0f;
            if (m_valid(x, y) == true) //上一帧对应像素是合法的
            {
                alpha = m_alpha;
                //alpha = 0.0f;
                Float3 pixelSum = Float3(0.0f);
                Float3 pixel2Sum = Float3(0.0f);
                for (int i = -neighborRadiance; i <= neighborRadiance; i++)//i in y line
                {
                    for (int j = -neighborRadiance; j <= neighborRadiance; j++) // j in x line
                    {
                        if ((x + j) >= 0 && (x + j) < width && (y + i) >= 0 && (y + i) < height)
                        {
                            pixelSum += curFilteredColor(x + j, y + i);
                            pixel2Sum += Sqr(curFilteredColor(x + j, y + i));
                            neighbotArea++;
                        }
                    }
                }
                Float3 pixelMean = pixelSum / (float)neighbotArea;
                Float3 pixelVariance = SafeSqrt(pixel2Sum / (float)neighbotArea - Sqr(pixelMean));
                color = Clamp(color, pixelMean - pixelVariance * m_colorBoxK, pixelMean + pixelVariance * m_colorBoxK);
            } 
            m_misc(x, y) = Lerp(color, curFilteredColor(x, y), alpha);
        }
    }
    std::swap(m_misc, m_accColor);
}

Buffer2D<Float3> Denoiser::Filter(const FrameInfo &frameInfo) {
    int height = frameInfo.m_beauty.m_height;
    int width = frameInfo.m_beauty.m_width;
    Buffer2D<Float3> filteredImage = CreateBuffer2D<Float3>(width, height);
    int kernelRadius = 16;
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Joint bilateral filter
            filteredImage(x, y) = Float3(0.0);//初始化为0.0
            float weightSum = 0.0f;
            for (int i = -kernelRadius; i <= kernelRadius; i++)//i in y line
            {
                for (int j = -kernelRadius; j <= kernelRadius; j++) //j in x line
                {
                    if ((x + j) >= 0 && (x + j) < width && (y + i) >= 0 && (y + i) < height)
                    {
                        //std::cout << j << " and " << i << std::endl; 
                        float DCoord = (Sqr(i) + Sqr(j)) / (2.0f * Sqr(m_sigmaCoord));//在assignment文档中，i表示(x,y)处像素,而j表示(x+j, y+i)处像素
                        float DColor = SqrLength(Abs(frameInfo.m_beauty(x, y) - frameInfo.m_beauty(x + j, y + i))) / (2.0f * Sqr(m_sigmaColor));
                        float DNormal = 0.0f;
                        if (std::fabs(Length(frameInfo.m_normal(x, y)) - 1.0f) < 0.01)//存在背景像素没有法线向量
                        {
                            DNormal = Sqr(SafeAcos(Dot(frameInfo.m_normal(x, y), frameInfo.m_normal(x + j, y + i)))) / (2.0f * Sqr(m_sigmaNormal));
                        }
                       
                        /*std::cout << "normal i is:(" << frameInfo.m_normal(x, y).x
                                  << frameInfo.m_normal(x, y).y
                                  << frameInfo.m_normal(x, y).z << std::endl;
                        std::cout << "normal i is:(" << frameInfo.m_normal(x + j, y + i).x
                                  << frameInfo.m_normal(x + j, y + i).y
                                  << frameInfo.m_normal(x + j, y + i).z << std::endl;*/
                        //std::cout << "dot is" << Dot(frameInfo.m_normal(x, y), frameInfo.m_normal(x + j, y + i)) << std::endl;
                        Float3 PixelsPositionDiffer = frameInfo.m_position(x + j, y + i) - frameInfo.m_position(x, y);
                        float DPlane = Sqr(Dot(frameInfo.m_normal(x, y),PixelsPositionDiffer / std::max(Length(PixelsPositionDiffer), 0.001f))) / (2.0f * Sqr(m_sigmaPlane));
                        float weight = std::exp(-DCoord - DColor - DNormal - DPlane);
                        /*std::cout << "coord:" << DCoord << "color:" << DColor << "normal:" << DNormal << "plane:" << DPlane << std::endl;
                        std::cout << weight << std::endl;*/
                        weightSum += weight;
                        filteredImage(x, y) += frameInfo.m_beauty(x + j, y + i) * weight;
                    }
                }
            }
            //std::cout << "weight sum is " << weightSum << std::endl;
            filteredImage(x, y) /= weightSum;
        }
    }

    return filteredImage;
}

void Denoiser::Init(const FrameInfo &frameInfo, const Buffer2D<Float3> &filteredColor) {
    m_accColor.Copy(filteredColor);
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    m_misc = CreateBuffer2D<Float3>(width, height);
    m_valid = CreateBuffer2D<bool>(width, height);
}

void Denoiser::Maintain(const FrameInfo &frameInfo) { m_preFrameInfo = frameInfo; }

Buffer2D<Float3> Denoiser::ProcessFrame(const FrameInfo &frameInfo) {
    // Filter current frame
    Buffer2D<Float3> filteredColor;
    filteredColor = Filter(frameInfo);

    // Reproject previous frame color to current
    if (m_useTemportal) {
        Reprojection(frameInfo);
        TemporalAccumulation(filteredColor);
    } else {
        Init(frameInfo, filteredColor);
    }

    // Maintain
    Maintain(frameInfo);
    if (!m_useTemportal) {
        m_useTemportal = true;
    }
    return m_accColor;
}
