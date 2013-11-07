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
#ifndef __itkTrainSingleNodeFilter_hxx
#define __itkTrainSingleNodeFilter_hxx

#include "itkTrainSingleNodeFilter.h"
#include "itkImageRegionIterator.h"
#include "itkIdentityTransform.h"
#include "itkContinuousIndex.h"
#include "itkImageDuplicator.h"

#include <vector>
#include <algorithm>
#include <functional>
#include <numeric>

#define EXTENT(_img) \
  { \
  ::itk::Point<double, Dimension> _point; \
  _img->TransformIndexToPhysicalPoint(_img->GetLargestPossibleRegion().GetIndex() + _img->GetLargestPossibleRegion().GetSize(), _point); \
  std::cout << "From: "<< _img->GetOrigin()<<" to: " << _point << std::endl; \
  } \

namespace itk
{



template< class TInputImage, class TOutputImage >
TrainSingleNodeFilter< TInputImage, TOutputImage >::TrainSingleNodeFilter()
  {
  this->SetNumberOfRequiredInputs(1);
  this->m_Transform = IdentityTransform< ScalarRealType, Dimension >::New();
  this->m_StateInterpolate = StateInterpolateType::New();
  this->m_OutputOrigin.Fill(0.0);
  this->m_OutputSpacing.Fill(10.); // One Centimeter is good!
  this->m_OutputDirection.SetIdentity();

  this->m_Size.Fill(30); // 30 centimeter
  this->m_OutputStartIndex.Fill(0.);

  }

template< class TInputImage, class TOutputImage >
void TrainSingleNodeFilter< TInputImage, TOutputImage >::SetOutputParametersFromImage(
    const ImageBaseType *image)
  {
  this->SetOutputOrigin(image->GetOrigin());
  this->SetSize(image->GetLargestPossibleRegion().GetSize());
  this->SetOutputSpacing(image->GetSpacing());
  this->SetOutputStartIndex(image->GetLargestPossibleRegion().GetIndex());
  this->SetOutputDirection(image->GetDirection());
  this->Modified();
  }

template< class TInputImage, class TOutputImage >
void TrainSingleNodeFilter< TInputImage, TOutputImage >::SetOutputParameterFromImageWithCustomSize(
    const ImageBaseType *iImage, const SizeType& oSize)
  {
  OutputImageType* oImage =
      static_cast< OutputImageType * >(this->ProcessObject::GetOutput(0));
  itkAssertOrThrowMacro(oImage, "No output Set");

  /** Position and orientation is defined by it's Origin and Direction */
  this->SetOutputOrigin(iImage->GetOrigin());
  this->SetOutputDirection(iImage->GetDirection());
  this->SetSize(oSize);

  SizeType iSize = iImage->GetLargestPossibleRegion().GetSize();
  SpacingType iSpacing = iImage->GetSpacing();
  SpacingType oSpacing;
  for (int i = 0; i < Dimension; i++)
    {
    oSpacing[i] = iSpacing[i] * iSize[i] / oSize[i];
    }
  this->SetOutputSpacing(oSpacing);
  this->UpdateOutputParameters();

  InputIndexType iIndex = iImage->GetLargestPossibleRegion().GetIndex();
  InputPointType iPoint;
  OutputIndexType oIndex;

  iImage->TransformIndexToPhysicalPoint(iIndex, iPoint);
  oImage->TransformPhysicalPointToIndex(iPoint, oIndex);
  this->SetOutputStartIndex(oIndex);

  this->Modified();
  }

//----------------------------------------------------------------------------
template< class TInputImage, class TOutputImage >
void TrainSingleNodeFilter< TInputImage, TOutputImage >::GenerateInputRequestedRegion()
  {
  // call the superclass's implementation of this method
  Superclass::GenerateInputRequestedRegion();

  if (!this->GetInput())
    {
    return;
    }

  // get pointers to the input and output
  InputImagePointer inputPtr = const_cast< TInputImage * >(this->GetInput());

  // Request the entire input image
  inputPtr->SetRequestedRegionToLargestPossibleRegion();
  MaskImageType *mask =
      static_cast< MaskImageType* >(this->ProcessObject::GetInput(1));
  if (mask)
    {
    mask->SetRequestedRegionToLargestPossibleRegion();
    }

  }
//----------------------------------------------------------------------------
template< class TInputImage, class TOutputImage >
void TrainSingleNodeFilter< TInputImage, TOutputImage >::GenerateOutputInformation()
  {
  // call the superclass' implementation of this method
  Superclass::GenerateOutputInformation();
  this->UpdateOutputParameters();

  // get pointers to the input and output
  InputImageType *inputPtr =
      static_cast< InputImageType * >(this->ProcessObject::GetInput(0));
  if (!inputPtr)
    {
    itkWarningMacro("Input not set!");
    return;
    }
  OutputImageType* outputPtr =
      static_cast< OutputImageType * >(this->ProcessObject::GetOutput(0));
  if (!outputPtr)
    {
    itkWarningMacro("Output not set!");
    return;
    }
  outputPtr->SetNumberOfComponentsPerPixel(
      StatisticsUpdate::MeasurementToStateDim(
          inputPtr->GetNumberOfComponentsPerPixel()));
  }
//----------------------------------------------------------------------------
template< class TInputImage, class TOutputImage >
void TrainSingleNodeFilter< TInputImage, TOutputImage >::GenerateData()
  {
  this->AllocateOutputs();

  InputImageType *inputImage =
      static_cast< InputImageType * >(this->ProcessObject::GetInput(0));
  OutputImageType* outputImage =
      static_cast< OutputImageType * >(this->ProcessObject::GetOutput(0));

  const MaskImageType* mask = GetMaskImage();
  itkAssertOrThrowMacro(inputImage, "Input image should be set.");
  itkAssertOrThrowMacro(m_Transform.IsNotNull(),
                        "Transformation function should be set.");

  this->SetInitialState();

  InputIteratorType iit(inputImage, inputImage->GetRequestedRegion());
  MaskIteratorType mit;
  if (mask) mit = MaskIteratorType(mask, mask->GetRequestedRegion());

  while (!iit.IsAtEnd())
    {
    if (!(mask && mit.Get() == 0))
      {
      MeasurementVectorType mv;
      NumericTraits< InputPixelType >::AssignToArray(iit.Get(), mv);

      InputPointType iPoint;
      inputImage->TransformIndexToPhysicalPoint(iit.GetIndex(), iPoint);
      OutputPointType oPoint = m_Transform->TransformPoint(iPoint);

      ContinuousIndexType oCountIndex;
      outputImage->TransformPhysicalPointToContinuousIndex(oPoint, oCountIndex);

      if (outputImage->GetBufferedRegion().IsInside(oCountIndex))
        {
        typename StateInterpolateType::NeighborListType neighList =
            m_StateInterpolate->GetWeightsForContinuousIndex(oCountIndex);
        for (int i = 0; i < neighList.size(); i++)
          {
          StateType state = outputImage->GetPixel(neighList[i].first);
          StatisticsUpdate::UpdateState(mv, state, neighList[i].second);
          outputImage->SetPixel(neighList[i].first, state);
          }
        }
      }
    ++iit;
    if (mask) ++mit;
    }
  }
template< class TInputImage, class TOutputImage >
void TrainSingleNodeFilter< TInputImage, TOutputImage >::SetInitialState()
  {
  InputImageType *inputImage =
      static_cast< InputImageType * >(this->ProcessObject::GetInput(0));
  itkAssertOrThrowMacro(inputImage, "Input image should be set.");

  OutputImageType* outputImage =
      static_cast< OutputImageType * >(this->ProcessObject::GetOutput(0));
  itkAssertOrThrowMacro(outputImage, "Output image should allocated.");

  const unsigned int inputLength = inputImage->GetNumberOfComponentsPerPixel();
  const unsigned int outputLength = StatisticsUpdate::MeasurementToStateDim(
      inputLength);

  if (m_InitialState.IsNotNull())
    {
    itkDebugMacro("Setting initial state");
    itkAssertOrThrowMacro(
        m_InitialState->GetNumberOfComponentsPerPixel()==outputLength,
        "Length of initial state does not match the input image.");
    OutputIteratorType oit(outputImage,
                           outputImage->GetLargestPossibleRegion());
    OutputConstIteratorType initit(m_InitialState,
                                   m_InitialState->GetLargestPossibleRegion());
    oit.GoToBegin();
    initit.GoToBegin();
    while (!oit.IsAtEnd())
      {
      oit.Set(initit.Get());
      ++oit;
      ++initit;
      }
    }
  else
    {
    OutputIteratorType oit(outputImage,
                           outputImage->GetLargestPossibleRegion());
    StateType zeroState;
    NumericTraits< StateType >::SetLength(zeroState, outputLength);
    zeroState.Fill(0.);
    oit.GoToBegin();
    while (!oit.IsAtEnd())
      {
      oit.Set(zeroState);
      ++oit;
      }
    itkDebugMacro("No initial state.");
    }
  m_StateInterpolate->SetInputImage(outputImage);
  }
template< class TInputImage, class TOutputImage >
void TrainSingleNodeFilter< TInputImage, TOutputImage >::UpdateOutputParameters()
  {
  OutputImageType* outputPtr =
      static_cast< OutputImageType * >(this->ProcessObject::GetOutput(0));
  if (!outputPtr)
    {
    itkWarningMacro("Output not set!");
    return;
    }
  OutputImageRegionType outputLargestPossibleRegion;
  outputLargestPossibleRegion.SetSize(m_Size);
  outputLargestPossibleRegion.SetIndex(m_OutputStartIndex);

  outputPtr->SetLargestPossibleRegion(outputLargestPossibleRegion);
  outputPtr->SetSpacing(m_OutputSpacing);
  outputPtr->SetOrigin(m_OutputOrigin);
  outputPtr->SetDirection(m_OutputDirection);
  }
template< class TInputImage, class TOutputImage >
void TrainSingleNodeFilter< TInputImage, TOutputImage >::PrintSelf(
    std::ostream & os, Indent indent) const
  {
  Superclass::PrintSelf(os, indent);

  os << indent << "Size: " << m_Size << std::endl;
  os << indent << "OutputStartIndex: " << m_OutputStartIndex << std::endl;
  os << indent << "OutputSpacing: " << m_OutputSpacing << std::endl;
  os << indent << "OutputOrigin: " << m_OutputOrigin << std::endl;
  os << indent << "OutputDirection: " << m_OutputDirection << std::endl;
  os << indent << "Transform: " << m_Transform << std::endl;
  }
} // end namespace itk

#endif
