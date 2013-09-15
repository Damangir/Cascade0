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
#ifndef __itkRobustMeanVariancePipeline_hxx
#define __itkRobustMeanVariancePipeline_hxx
#include "itkRobustMeanVariancePipeline.h"

#include "itkNumericTraits.h"
#include "3rdparty/gnuplot-cpp/gnuplot_i.hpp"

#include <fstream>
#include <iostream>

namespace itk
{

template< class TInputImage >
RobustMeanVariancePipeline< TInputImage >::RobustMeanVariancePipeline()
  {
  m_NumOfComponents = 1;
  m_Percentile = 0.05;
  m_NumberOfBins = 100;

  imageToHistogramFilter = ImageToHistogramFilterType::New();
  covarianceAlgorithm = CovarianceAlgorithmType::New();
  this->SetMaskValue(NumericTraits< MaskPixelType >::max());

  ProcessObject::SetNthOutput(
      1, static_cast< MeanObjectType * >(MakeOutput(1).GetPointer()));
  ProcessObject::SetNthOutput(
      2, static_cast< CovarianceObjectType * >(MakeOutput(2).GetPointer()));
  }

template< class TInputImage >
void RobustMeanVariancePipeline< TInputImage >::PrintSelf(std::ostream & os,
                                                          Indent indent) const
  {
  Superclass::PrintSelf(os, indent);
  os << indent << "Number of bins " << m_NumberOfBins << std::endl;
  os << indent << "Percentile " << m_Percentile << std::endl;
  os << indent << "Number of components " << m_NumOfComponents << std::endl;
  }

template< class TInputImage >
void RobustMeanVariancePipeline< TInputImage >::GenerateData()
  {
  m_NumOfComponents = this->GetInput()->GetNumberOfComponentsPerPixel();

  if (m_Percentile > 1 || m_Percentile < 0)
    {
    itkExceptionMacro("Histogram percentile should be lie in range (0, 1)");
    }
  if (m_Percentile > 0.5)
    {
    itkWarningMacro("Histogram percentile adjusted to range (0, 0.5)");
    m_Percentile = 1 - m_Percentile;
    }

  SizeType size(m_NumOfComponents);
  size.Fill(m_NumberOfBins);

  if (this->GetMaskImage())
    {
    imageToHistogramFilter->SetMaskValue(this->GetMaskValue());
    imageToHistogramFilter->SetMaskImage(this->GetMaskImage());
    }
  imageToHistogramFilter->SetInput(this->GetInput());
  imageToHistogramFilter->SetHistogramSize(size);
  imageToHistogramFilter->SetAutoMinimumMaximum(true);
  imageToHistogramFilter->Update();

  MeasurementVectorType lowerBound(m_NumOfComponents);
  MeasurementVectorType upperBound(m_NumOfComponents);
  HistogramType *hist = imageToHistogramFilter->GetOutput();
  for (unsigned int i = 0; i < m_NumOfComponents; i++)
    {
    lowerBound[i] = hist->Quantile(i, m_Percentile);
    upperBound[i] = hist->Quantile(i, 1 - m_Percentile);
    size[i] = int(upperBound[i] - lowerBound[i]);
    }
  imageToHistogramFilter->SetHistogramSize(size);
  imageToHistogramFilter->SetAutoMinimumMaximum(false);
  imageToHistogramFilter->SetHistogramBinMinimum(lowerBound);
  imageToHistogramFilter->SetHistogramBinMaximum(upperBound);
  imageToHistogramFilter->Update();

  covarianceAlgorithm->SetInput(imageToHistogramFilter->GetOutput());
  covarianceAlgorithm->Update();

  MeanType mean = covarianceAlgorithm->GetMean();
  CovarianceType cov = covarianceAlgorithm->GetCovarianceMatrix();

  this->GetMeanOutput()->Set(mean);
  this->GetCovarianceOutput()->Set(cov);
  }

template< class TInputImage >
typename RobustMeanVariancePipeline< TInputImage >::MeanObjectType *
RobustMeanVariancePipeline< TInputImage >::GetMeanOutput()
  {
  return static_cast< MeanObjectType * >(this->ProcessObject::GetOutput(1));
  }
template< class TInputImage >
const typename RobustMeanVariancePipeline< TInputImage >::MeanObjectType *
RobustMeanVariancePipeline< TInputImage >::GetMeanOutput() const
  {
  return static_cast< const MeanObjectType * >(this->ProcessObject::GetOutput(1));
  }

template< class TInputImage >
typename RobustMeanVariancePipeline< TInputImage >::CovarianceObjectType *
RobustMeanVariancePipeline< TInputImage >::GetCovarianceOutput()
  {
  return static_cast< CovarianceObjectType * >(this->ProcessObject::GetOutput(2));
  }
template< class TInputImage >
const typename RobustMeanVariancePipeline< TInputImage >::CovarianceObjectType *
RobustMeanVariancePipeline< TInputImage >::GetCovarianceOutput() const
  {
  return static_cast< const CovarianceObjectType * >(this->ProcessObject::GetOutput(
      2));
  }

template< class TInputImage >
void RobustMeanVariancePipeline< TInputImage >::AllocateOutputs()
  {
  // Pass the input through as the output
  InputImagePointer image = const_cast< TInputImage * >(this->GetInput());

  this->GraftOutput(image);

  // Nothing that needs to be allocated for the remaining outputs
  }
template< class TInputImage >
DataObject::Pointer RobustMeanVariancePipeline< TInputImage >::MakeOutput(
    DataObjectPointerArraySizeType output)
  {
  switch (output)
    {
  case 0:
    return static_cast< DataObject * >(TInputImage::New().GetPointer());
    break;
  case 1:
    return static_cast< DataObject * >(MeanObjectType::New().GetPointer());
    break;
  case 2:
    return static_cast< DataObject * >(CovarianceObjectType::New().GetPointer());
    break;
  default:
    // might as well make an image
    return static_cast< DataObject * >(TInputImage::New().GetPointer());
    break;
    }
  }

} // end namespace itk

#endif
