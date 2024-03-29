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
#ifndef __itkRobustOutlierPipeline_hxx
#define __itkRobustOutlierPipeline_hxx
#include "itkRobustOutlierPipeline.h"

#include "itkMultiplyImageFilter.h"
#include "util/itkOrientationEnhanceFilter.h"
#include "util/helpers.h"
namespace itk
{

template< class TInputImage, class TOutputImage >
RobustOutlierPipeline< TInputImage, TOutputImage >::RobustOutlierPipeline()
  {
  this->SetMaskValue(NumericTraits< MaskPixelType >::max());
  m_MahalanobisFilter = MahalanobisDistanceImageFilterType::New();
  m_MeanCovCalculator = MeanVariancePipelineType::New();
  m_ChiFilter = ChiFilterType::New();
  m_Castor = CastToOutputType::New();
  }

template< class TInputImage, class TOutputImage >
void RobustOutlierPipeline< TInputImage, TOutputImage >::PrintSelf(
    std::ostream & os, Indent indent) const
  {
  Superclass::PrintSelf(os, indent);
  }

template< class TInputImage, class TOutputImage >
void RobustOutlierPipeline< TInputImage, TOutputImage >::GenerateData()
  {
  InputImageType *inputImage =
      static_cast< InputImageType * >(this->ProcessObject::GetInput(0));

  itkAssertOrThrowMacro(inputImage, "Input image should be set.");

  m_MahalanobisFilter->SetInput(inputImage);
  if (GetMaskImage())
    {
    m_MahalanobisFilter->SetMaskImage(this->GetMaskImage());
    m_MahalanobisFilter->SetMaskValue(this->GetMaskValue());
    }

  if (!m_MahalanobisFilter->GetStateImage())
    {
    if (GetMaskImage())
      {
      m_MeanCovCalculator->SetMaskImage(this->GetMaskImage());
      m_MeanCovCalculator->SetMaskValue(this->GetMaskValue());
      }

    m_MeanCovCalculator->SetInput(inputImage);
    m_MeanCovCalculator->Update();
    m_MahalanobisFilter->SetGlobalState(
        StateFunc::GetState(GetMean(), GetCovariance()));
    }

  m_ChiFilter->GetFunctor().SetDOF(inputImage->GetNumberOfComponentsPerPixel());
  m_ChiFilter->SetInput(m_MahalanobisFilter->GetDistanceImage());
  m_ChiFilter->Update();
  typename ScalarImageType::Pointer out_img = m_ChiFilter->GetOutput();

  if (m_PerformOrient)
    {
    typedef MultiplyImageFilter< ScalarImageType, ScalarImageType > MultiplyImageFilterType;
    typename MultiplyImageFilterType::Pointer multiplyFilter =
        MultiplyImageFilterType::New();
    typedef OrientationEnhanceFilter< ScalarImageType > OrientEnhanceType;
    typename OrientEnhanceType::Pointer orientEnhance =
        OrientEnhanceType::New();

    multiplyFilter->SetInput1(out_img);
    multiplyFilter->SetInput2(m_MahalanobisFilter->GetOrientImage());
    orientEnhance->SetInput(multiplyFilter->GetOutput());
    orientEnhance->Update();
    out_img = orientEnhance->GetOutput();
    }

  m_Castor->SetInput(out_img);

  m_Castor->Update();
  this->GraftOutput(m_Castor->GetOutput());

  }

} // end namespace itk

#endif
