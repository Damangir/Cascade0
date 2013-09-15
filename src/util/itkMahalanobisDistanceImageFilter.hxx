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
#ifndef __itkMahalanobisDistanceImageFilter_hxx
#define __itkMahalanobisDistanceImageFilter_hxx

#include "itkMahalanobisDistanceImageFilter.h"
#include "itkImageRegionIterator.h"
#include "itkIdentityTransform.h"
#include "itkContinuousIndex.h"
#include "itkImageDuplicator.h"

namespace itk
{
//----------------------------------------------------------------------------
template< class TInputImage, class TOutputImage >
MahalanobisDistanceImageFilter< TInputImage, TOutputImage >::MahalanobisDistanceImageFilter()
  {
  this->SetNumberOfRequiredInputs(1);
  this->m_Transform = IdentityTransform< ScalarRealType, Dimension >::New();
  this->m_StateInterpolator = StateInterpolateType::New();
  this->SetMaskValue(NumericTraits< MaskPixelType >::max());
  m_HasStateImage = false;
  m_HasGlobalState = false;
  m_HasMask = false;
  m_OutsideValue = NumericTraits< OutputPixelType >::ZeroValue();
  /** Binary not of zero. All bits set. */
  m_PositiveOrientation = ~(0);

  }
template< class TInputImage, class TOutputImage >
void MahalanobisDistanceImageFilter< TInputImage, TOutputImage >::BeforeThreadedGenerateData()
  {
  InputImageType *inputImage =
      static_cast< InputImageType * >(this->ProcessObject::GetInput(0));
  itkAssertOrThrowMacro(inputImage, "Input image should be set.");

  m_HasMask = this->GetMaskImage() != 0;
  m_HasGlobalState = NumericTraits< StateType >::GetLength(m_GlobalState) != 0;
  m_HasStateImage = m_StateImage.IsNotNull();

  if (!m_StateImage)
    {
    itkAssertOrThrowMacro(
        m_HasGlobalState,
        "Either global status or status image should be set.");
    }
  else
    {
    itkAssertOrThrowMacro(m_Transform.IsNotNull(),
                          "Transformation function should be set.");
    m_StateInterpolator->SetInputImage(m_StateImage);
    if (!m_HasGlobalState)
      {
      m_GlobalState.Fill(0.);
      }
    }
  int orientMask = (1 << inputImage->GetNumberOfComponentsPerPixel()) - 1;
  m_PositiveOrientation &= orientMask;
  }
//----------------------------------------------------------------------------
template< class TInputImage, class TOutputImage >
void MahalanobisDistanceImageFilter< TInputImage, TOutputImage >::ThreadedGenerateData(
    const OutputImageRegionType & outputRegionForThread, ThreadIdType threadId)
  {

  InputImageType *inputImage =
      static_cast< InputImageType * >(this->ProcessObject::GetInput(0));

  OutputImageType* outputImage =
      static_cast< OutputImageType * >(this->ProcessObject::GetOutput(0));

  StateType state = m_GlobalState;
  if (!m_HasStateImage) StateFunc::MakeReady(state);

  InputIteratorType iit(inputImage, outputRegionForThread);
  OutputIteratorType oit(outputImage, outputRegionForThread);

  MaskIteratorType mit;
  MaskPixelType  maskValue;
  if (m_HasMask)
    {
    mit = MaskIteratorType(GetMaskImage(), outputRegionForThread);
    maskValue = this->GetMaskValue();
    }

  while (!iit.IsAtEnd())
    {
    if (m_HasMask && mit.Get() != maskValue)
      {
      oit.Set(m_OutsideValue);
      }
    else
      {
      if (m_HasStateImage)
        {
        InputPointType iPoint;
        inputImage->TransformIndexToPhysicalPoint(iit.GetIndex(), iPoint);
        StatePointType sPoint = m_Transform->TransformPoint(iPoint);
        if (m_StateInterpolator->IsInsideBuffer(sPoint))
          {
          state = m_StateInterpolator->Evaluate(sPoint);
          }
        else
          {
          state = m_GlobalState;
          }
        StateFunc::MakeReady(state);
        }

      if (StateFunc::IsValid(state))
        {
        MeasurementVectorType mv;
        NumericTraits< InputPixelType >::AssignToArray(iit.Get(), mv);
        OutputPixelType out = StateFunc::Distance(state, mv);
        if (m_HasStateImage)
          {
          /*
           * State image implies no orientation.
           * In the current implementation orientation with respect to
           * calculated state image is not accurate so orientation is discarded.
           *
           * This implies that this filter will capture abnormalities in the
           * image and does not care about its location. I.e. a dark point in
           * a brain can be atrophy but this filter capture it as a lesion.
           * This behavior should be seen in interpreting the output likelihood.
           */
          oit.Set(out);
          }
        else
          {
          if (StateFunc::Orientation(state, mv) == m_PositiveOrientation)
            oit.Set(out);
          else
            oit.Set(-out);
          }
        }
      else
        {
        oit.Set(m_OutsideValue);
        }
      }
    ++iit;
    ++oit;
    if (m_HasMask) ++mit;
    }
  }

template< class TInputImage, class TOutputImage >
void MahalanobisDistanceImageFilter< TInputImage, TOutputImage >::PrintSelf(
    std::ostream & os, Indent indent) const
  {
  Superclass::PrintSelf(os, indent);
  os << indent << "Transform: " << m_Transform << std::endl;
  }
} // end namespace itk

#endif
