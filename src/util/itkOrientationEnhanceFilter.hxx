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
#ifndef __itkOrientationEnhanceFilter_hxx
#define __itkOrientationEnhanceFilter_hxx
#include "itkOrientationEnhanceFilter.h"

#include "itkConstNeighborhoodIterator.h"
#include "itkNeighborhoodInnerProduct.h"
#include "itkImageRegionIterator.h"
#include "itkNeighborhoodAlgorithm.h"
#include "itkOffset.h"
#include "itkProgressReporter.h"

#include <vector>
#include <algorithm>

namespace itk
{
template< class TInputImage, class TOutputImage >
OrientationEnhanceFilter< TInputImage, TOutputImage >::OrientationEnhanceFilter()
  {
  }

template< class TInputImage, class TOutputImage >
void OrientationEnhanceFilter< TInputImage, TOutputImage >::ThreadedGenerateData(
    const OutputImageRegionType & outputRegionForThread, ThreadIdType threadId)
  {
  typename OutputImageType::Pointer output = this->GetOutput();
  typename InputImageType::ConstPointer input = this->GetInput();

  NeighborhoodAlgorithm::ImageBoundaryFacesCalculator< InputImageType > bC;
  typename NeighborhoodAlgorithm::ImageBoundaryFacesCalculator< InputImageType >::FaceListType faceList =
      bC(input, outputRegionForThread, this->GetRadius());

  ProgressReporter progress(this, threadId,
                            outputRegionForThread.GetNumberOfPixels());

  ZeroFluxNeumannBoundaryCondition< InputImageType > nbc;
  std::vector< InputPixelType > pixels;
  InputPixelType sum;

  for (typename NeighborhoodAlgorithm::ImageBoundaryFacesCalculator<
      InputImageType >::FaceListType::iterator fit = faceList.begin();
      fit != faceList.end(); ++fit)
    {
    ImageRegionIterator< OutputImageType > it = ImageRegionIterator<
        OutputImageType >(output, *fit);

    ConstNeighborhoodIterator< InputImageType > bit = ConstNeighborhoodIterator<
        InputImageType >(this->GetRadius(), input, *fit);
    bit.OverrideBoundaryCondition(&nbc);
    bit.GoToBegin();
    const unsigned int neighborhoodSize = bit.Size();
    const unsigned int medianPosition = neighborhoodSize / 2;
    while (!bit.IsAtEnd())
      {
      pixels.resize(neighborhoodSize);
      sum=0;
      for (unsigned int i = 0; i < neighborhoodSize; ++i)
        {
        pixels[i] = (bit.GetPixel(i));
        sum += pixels[i];
        }

      // get the median value
      const typename std::vector< InputPixelType >::iterator medianIterator =
          pixels.begin() + medianPosition;
      std::nth_element(pixels.begin(), medianIterator, pixels.end());

      OutputPixelType outVal =
          static_cast< OutputPixelType >(bit.GetCenterPixel());

      if (sum * bit.GetCenterPixel() < 0)
        {
        outVal *= -1;
        }

      it.Set(outVal);

      ++bit;
      ++it;
      progress.CompletedPixel();
      }
    }
  }
} // end namespace itk

#endif
