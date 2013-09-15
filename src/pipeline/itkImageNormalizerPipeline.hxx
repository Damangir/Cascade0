/*
 * Copyright (C) 2013 Soheil Damangir - All Rights Reserved
 * You may use and distribute, but not modify this code under the terms of the
 * Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License
 * under the following conditions:
 *
 * Attribution — You must attribute the work in the manner specified by the
 * author or licensor (but not in any way that suggests that they endorse you
 * or your use of the work).
 * Noncommercial — You may not use this work for commercial purposes.
 * No Derivative Works — You may not alter, transform, or build upon this
 * work
 *
 * To view a copy of the license, visit
 * http://creativecommons.org/licenses/by-nc-nd/3.0/
 */
#ifndef __itkImageNormalizerPipeline_hxx
#define __itkImageNormalizerPipeline_hxx
#include "itkImageNormalizerPipeline.h"

#include <vector>
#include <algorithm>
#include <numeric>
#include <cmath>

#include "itkIntTypes.h"
#include "itkNumericTraits.h"
#include "itkUnaryFunctorImageFilter.h"
#include "itkDiscreteGaussianImageFilter.h"
#include "itkMaskImageFilter.h"
#include "itkMaskedImageToHistogramFilter.h"
#include "itkBinaryThresholdImageFilter.h"

#include "util/itkLinearTransformFunctor.h"
#include "3rdparty/gnuplot-cpp/gnuplot_i.hpp"

namespace itk
{
template< class TInputImage, class TOutputImage >
ImageNormalizerPipeline< TInputImage, TOutputImage >::ImageNormalizerPipeline()
  {
  m_TargetMin = -1;
  m_TargetPeak = -1;
  m_TargetMax = -1;

  m_MinValue = 0;
  m_Peak = 0;
  m_MaxValue = 0;

  m_Percentile = 0.05;
  m_NumberOfBins = 100;
  }

template< class TInputImage, class TOutputImage >
void ImageNormalizerPipeline< TInputImage, TOutputImage >::PrintSelf(
    std::ostream & os, Indent indent) const
  {
  Superclass::PrintSelf(os, indent);
  os << indent << "Peak target intensity " << m_TargetPeak << std::endl;
  os << indent << "Max target intensity " << m_MaxValue << std::endl;
  os << indent << "Number of bins " << m_NumberOfBins << std::endl;
  os << indent << "Percentile " << m_Percentile << std::endl;

  os << indent << "Estimated peak intensity " << m_Peak << std::endl;
  }

template< class TInputImage, class TOutputImage >
void ImageNormalizerPipeline< TInputImage, TOutputImage >::GenerateData()
  {
  unsigned int m_NumOfComponents = 1;
  if (m_Percentile > 1 || m_Percentile < 0)
    {
    itkExceptionMacro("Histogram percentile should be lie in range (0, 1)");
    }
  if (m_Percentile > 0.5)
    {
    itkWarningMacro("Histogram percentile adjusted to range (0, 0.5)");
    m_Percentile = 1 - m_Percentile;
    }

  typedef InputImageType MaskImageType;
  typedef BinaryThresholdImageFilter< InputImageType, MaskImageType > BinaryThresholdImageFilterType;

  typedef Statistics::MaskedImageToHistogramFilter< InputImageType,
      MaskImageType > HistogramGeneratorType;
  typedef typename HistogramGeneratorType::HistogramType HistogramType;

  typedef DiscreteGaussianImageFilter< InputImageType, InputImageType > GaussianFilterType;

  typedef UnaryFunctorImageFilter< InputImageType, OutputImageType,
      IntensityLinearTransform< InputImagePixelType, OutputImagePixelType > > LinearTransform;

  /** First create a mask of non-zero regions of the input image zero/max */
  typename BinaryThresholdImageFilterType::Pointer thresholdFilter =
      BinaryThresholdImageFilterType::New();
  thresholdFilter->SetInput(this->GetInput());
  thresholdFilter->SetLowerThreshold(
      NumericTraits< typename MaskImageType::PixelType >::epsilon());
  thresholdFilter->SetInsideValue(1);
  thresholdFilter->Update();

  /** Then blur the image to reduce noise  */
  typename GaussianFilterType::Pointer gaussianFilter =
      GaussianFilterType::New();
  gaussianFilter->SetInput(this->GetInput());
  gaussianFilter->SetVariance(1);

  /** Generate histogram for area non zero area */
  typename HistogramGeneratorType::Pointer histogramGenerator =
      HistogramGeneratorType::New();
  typename HistogramGeneratorType::HistogramType::SizeType size(
      m_NumOfComponents);
  size.Fill(m_NumberOfBins);

  histogramGenerator->SetInput(gaussianFilter->GetOutput());
  histogramGenerator->SetMaskImage(thresholdFilter->GetOutput());
  histogramGenerator->SetMaskValue(thresholdFilter->GetInsideValue());

  histogramGenerator->SetHistogramSize(size);
  histogramGenerator->SetAutoMinimumMaximum(true);
  histogramGenerator->Update();

  /** Get top and bottom percentile as new bound */
  typename HistogramType::MeasurementVectorType lowerBound(m_NumOfComponents);
  typename HistogramType::MeasurementVectorType upperBound(m_NumOfComponents);
  for (unsigned int i = 0; i < m_NumOfComponents; i++)
    {
    lowerBound[i] = histogramGenerator->GetOutput()->Quantile(i, m_Percentile);
    upperBound[i] = histogramGenerator->GetOutput()->Quantile(i,
                                                              1 - m_Percentile);
    }
  /** save the extreme landmark by the way */
  m_MaxValue = upperBound[0];
  m_MinValue = lowerBound[0];

  /** Regenerate histogram using new bound */
  histogramGenerator->SetAutoMinimumMaximum(false);
  histogramGenerator->SetHistogramBinMinimum(lowerBound);
  histogramGenerator->SetHistogramBinMaximum(upperBound);
  histogramGenerator->Update();

  /* Filter the output histogram to avoid unstable peaks */
  HistogramType * histogram =
      const_cast< HistogramType * >(histogramGenerator->GetOutput());
  const int histogramSize = histogram->Size();

  std::vector< double > freqs;
  std::vector< double > measurements;
  freqs.assign(histogramSize, 0.0);
  measurements.assign(histogramSize, 0.0);

  double gausian[] =
    {
    0.25, 0.50, 0.25
    };
  const int g_size = 1;
  const int median_size = 2;
  int bin = 0;
  /** Putting to vector  */
  for (bin = 0; bin < histogramSize; bin++)
    {
    measurements[bin] = histogram->GetMeasurementVector(bin)[0];
    }

  /** Median filter on histogram to avoid salt-pepper noise  */
  for (bin = 0; bin < histogramSize; bin++)
    {
    std::vector< double > neighbor;
    unsigned int from_bin = std::max(0, bin - g_size);
    unsigned int to_bin = std::min(histogramSize, bin + g_size);
    for (int i = from_bin; i < to_bin; i++)
      {
      neighbor.push_back(histogram->GetFrequency(i));
      }
    std::sort(neighbor.begin(), neighbor.end());
    freqs[bin] = *(neighbor.begin() + int(g_size / 2));
    }
  /** Gaussian Filter to avoid high frequencies*/
  for (bin = 0; bin < histogramSize; bin++)
    {
    double val = 0;
    double coef = 0;
    unsigned int from_bin = std::max(0, bin - g_size);
    unsigned int to_bin = std::min(histogramSize, bin + g_size);
    for (int i = from_bin; i < to_bin; i++)
      {
      val += freqs[i] * gausian[bin - i];
      coef += gausian[bin - i];
      }
    freqs[bin] = val / coef;
    histogram->SetFrequency(bin, freqs[bin]);
    }

  /** Calculate the stable peak (mode) of the histogram */
  unsigned int peakBin = 0;

  double peak_begin = histogram->Quantile(0, 0.10);
  double peak_end = histogram->Quantile(0, 0.90);

  for (int i = 0; i < histogramSize; i++)
    {
    double intensity = histogram->GetMeasurementVector(i)[0];
    if (intensity > peak_begin && intensity < peak_end
        && (freqs[i] > freqs[peakBin] || peakBin == 0))
      {
      peakBin = i;
      }
    }

  m_Peak = histogram->GetMeasurementVector(peakBin)[0];

  if (false)
    {
    std::vector<double> x_intensity, y_freq;
    for (int i = 0; i < histogramSize; i++)
      {
      double intensity = histogram->GetMeasurementVector(i)[0];
      x_intensity.push_back(intensity);
      y_freq.push_back(freqs[i]);
      }
    Gnuplot(x_intensity, y_freq, "Histogram", "lines", "Intensity", "Frequency");
    }
  /* Linearly map peak and extreme landmarks to desired valuse */
  typename LinearTransform::Pointer linearTransform = LinearTransform::New();
  linearTransform->SetInput(this->GetInput());
  linearTransform->GetFunctor().AddFixedPoint(0, 0);

  if (m_TargetPeak > 0)
    {
    linearTransform->GetFunctor().AddFixedPoint(m_Peak, m_TargetPeak);
    }
  if (m_TargetMin > 0)
    {
    linearTransform->GetFunctor().AddFixedPoint(lowerBound[0], m_TargetMin);
    }
  if (m_TargetMax > 0)
    {
    linearTransform->GetFunctor().AddFixedPoint(upperBound[0], m_TargetMax);
    }

  linearTransform->Update();

  this->GraftOutput(linearTransform->GetOutput());
  }
} // end namespace itk

#endif
