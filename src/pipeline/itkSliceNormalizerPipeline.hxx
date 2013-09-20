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
#ifndef __itkSliceNormalizerPipeline_hxx
#define __itkSliceNormalizerPipeline_hxx
#include "itkSliceNormalizerPipeline.h"

#include "itkImageAlgorithm.h"
#include "itkUnaryFunctorImageFilter.h"

#include "util/itkIntensityTableLookupFunctor.h"
#include "3rdparty/gnuplot-cpp/gnuplot_i.hpp"

namespace itk
{
template< class TInputImage >
SliceNormalizerPipeline< TInputImage >::SliceNormalizerPipeline()
  {
  m_NumberOfLevels = 100;
  m_Percentile = 0.02;
  this->SetDimToFold(SliceDimension);
  this->SetMaskValue(NumericTraits< MaskImagePixelType >::max());
  }

template< class TInputImage >
void SliceNormalizerPipeline< TInputImage >::PrintSelf(std::ostream & os,
                                                       Indent indent) const
  {
  Superclass::PrintSelf(os, indent);
  }

template< class TInputImage >
void SliceNormalizerPipeline< TInputImage >::GenerateData()
  {
  this->AllocateOutputs();

  /** First calculate the overall image histogram */
  typename ImageHistogramType::Pointer imgHistogram = ImageHistogramType::New();
  typename ImageHistogramType::HistogramType::SizeType size(1);
  size.Fill(m_NumberOfLevels);
  imgHistogram->SetInput(this->GetInput());
  imgHistogram->SetMaskImage(this->GetMaskImage());
  imgHistogram->SetMaskValue(this->GetMaskValue());
  imgHistogram->SetHistogramSize(size);
  imgHistogram->SetAutoMinimumMaximum(true);
  imgHistogram->Update();

  m_MinValue = imgHistogram->GetOutput()->Quantile(0, m_Percentile);
  m_MaxValue = imgHistogram->GetOutput()->Quantile(0, 1 - m_Percentile);
  m_MeanValue = imgHistogram->GetOutput()->Quantile(0, 0.5);

  const typename InputImageType::RegionType requestedRegion =
      this->GetInput()->GetLargestPossibleRegion();

  const typename InputImageType::IndexType requestedIndex =
      requestedRegion.GetIndex();
  const typename InputImageType::SizeType requestedSize =
      requestedRegion.GetSize();

  typename SliceType::RegionType internalRegion;
  unsigned int internal_i = 0;
  for (unsigned int i = 0; internal_i < SliceDimension; ++i, ++internal_i)
    {
    if (i == GetDimToFold()) ++i;

    internalRegion.SetSize(internal_i, requestedSize[i]);
    internalRegion.SetIndex(internal_i, requestedIndex[i]);
    }

  const IndexValueType sliceRangeMax =
      static_cast< IndexValueType >(requestedSize[GetDimToFold()]
          + requestedIndex[GetDimToFold()]);

  for (IndexValueType slice_n = requestedIndex[GetDimToFold()];
      slice_n < sliceRangeMax; ++slice_n)
    {
    typename InputImageType::RegionType currentRegion = requestedRegion;
    currentRegion.SetIndex(GetDimToFold(), slice_n);
    currentRegion.SetSize(GetDimToFold(), 1);
    itkAssertOrThrowMacro(
        currentRegion.GetNumberOfPixels() == internalRegion.GetNumberOfPixels(),
        "Number of pixels in slice and image regions does not match");

    typename SliceType::Pointer slice = SliceType::New();
    slice->SetRegions(internalRegion);
    slice->Allocate();
    ImageAlgorithm::Copy(this->GetInput(), slice.GetPointer(), currentRegion,
                         internalRegion);

    typename MaskSliceType::Pointer mask = MaskSliceType::New();
    mask->SetRegions(internalRegion);
    mask->Allocate();
    ImageAlgorithm::Copy(this->GetMaskImage(), mask.GetPointer(), currentRegion,
                         internalRegion);

    /** Create histogram */
    typename SliceHistogramType::Pointer slcHistogram =
        SliceHistogramType::New();
    typename SliceHistogramType::HistogramType::SizeType size(1);
    size.Fill(m_NumberOfLevels);
    slcHistogram->SetInput(slice);
    slcHistogram->SetMaskImage(mask);
    slcHistogram->SetMaskValue(this->GetMaskValue());
    slcHistogram->SetHistogramSize(size);
    slcHistogram->SetAutoMinimumMaximum(true);
    slcHistogram->Update();

    /** Calculate robust measures */
    InputImagePixelType SliceMinValue = slcHistogram->GetOutput()->Quantile(
        0, m_Percentile);
    InputImagePixelType SliceMeanValue = slcHistogram->GetOutput()->Quantile(
        0, 0.5);
    InputImagePixelType SliceMaxValue = slcHistogram->GetOutput()->Quantile(
        0, 1 - m_Percentile);

    typedef IntensityTableLookupFunctor< InputImagePixelType,
        OutputImagePixelType > LookupFunctorType;
    typedef UnaryFunctorImageFilter< SliceType, SliceType, LookupFunctorType > LookupTransform;

    LookupFunctorType lookupFunctor;
    lookupFunctor.AddLookupRow(0, 0);
    lookupFunctor.AddLookupRow(SliceMeanValue, m_MeanValue);

    /* Linearly map peak and extreme landmarks to desired valuse */
    typename LookupTransform::Pointer lookupTransform = LookupTransform::New();
    lookupTransform->SetInput(slice);
    lookupTransform->SetFunctor(lookupFunctor);
    lookupTransform->Update();

    ImageAlgorithm::Copy(lookupTransform->GetOutput(), this->GetOutput(0),
                         internalRegion, currentRegion);

    }
  }

} // end namespace itk
#include "itkSliceBySliceImageFilter.hxx"
#endif
