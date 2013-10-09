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
#ifndef __itkIntensityNormalizerPipeline_hxx
#define __itkIntensityNormalizerPipeline_hxx
#include "itkIntensityNormalizerPipeline.h"

namespace itk
{
template< class TInputImage, class TOutputImage, class TMaskImage >
IntensityNormalizerPipeline< TInputImage, TOutputImage, TMaskImage >::IntensityNormalizerPipeline()
  {
  m_NumberOfLevels = 100;
  this->SetMaskValue(NumericTraits< MaskPixelType >::max());
  }

template< class TInputImage, class TOutputImage, class TMaskImage >
void IntensityNormalizerPipeline< TInputImage, TOutputImage, TMaskImage >::PrintSelf(
    std::ostream & os, Indent indent) const
  {
  Superclass::PrintSelf(os, indent);
  os << indent << "Number of levels " << m_NumberOfLevels << std::endl;
  }

template< class TInputImage, class TOutputImage, class TMaskImage >
void IntensityNormalizerPipeline< TInputImage, TOutputImage, TMaskImage >::GenerateData()
  {
  const unsigned int numElems =
      this->GetInput()->GetNumberOfComponentsPerPixel();

  itkAssertOrThrowMacro(numElems == 1, "Input should be an scalar image");

  /** Then blur the image to reduce noise  */
  typename GaussianFilterType::Pointer gaussianFilter =
      GaussianFilterType::New();
  gaussianFilter->SetInput(this->GetInput());
  gaussianFilter->SetVariance(1);

  /** Generate histogram for area non zero area */
  typename HistogramGeneratorType::Pointer histogramGenerator =
      HistogramGeneratorType::New();
  typename HistogramGeneratorType::HistogramType::SizeType size(numElems);
  size.Fill(m_NumberOfLevels);

  histogramGenerator->SetInput(gaussianFilter->GetOutput());
  histogramGenerator->SetMaskImage(this->GetMaskImage());
  histogramGenerator->SetMaskValue(this->GetMaskValue());

  histogramGenerator->SetHistogramSize(size);
  histogramGenerator->SetAutoMinimumMaximum(true);
  histogramGenerator->Update();

  LookupFunctorType lookupFunctor;
  /*
   * We want to normalize the normal part (i.e. the middle part of the histogram
   * for that the abnormalities usually lies in the rest)
   */
  for (int i = 5; i <= 95 ; i++)
    {
    const double ratio = i * 0.01;

    InputImagePixelType levelIntensity =
        histogramGenerator->GetOutput()->Quantile(0, ratio);
    lookupFunctor.AddLookupRow(levelIntensity, ratio);
    }
  lookupFunctor.AddLookupRow(0, 0);

  /* Linearly map peak and extreme landmarks to desired valuse */
  typename LookupTransform::Pointer lookupTransform = LookupTransform::New();
  lookupTransform->SetInput(this->GetInput());
  lookupTransform->SetFunctor(lookupFunctor);
  lookupTransform->Update();

  this->GraftOutput(lookupTransform->GetOutput());
  }
} // end namespace itk

#endif
