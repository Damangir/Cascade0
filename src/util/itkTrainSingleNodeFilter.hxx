/*=========================================================================
 *
 *  Copyright Insight Software Consortium
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0.txt
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 *=========================================================================*/
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
    const ImageBaseType *image, const SizeType& size)
  {
  /** Position and orientation is defined by it's Origin and Direction */
  this->SetOutputOrigin(image->GetOrigin());
  this->SetOutputDirection(image->GetDirection());
  this->SetSize(size);

  SizeType oSize = image->GetLargestPossibleRegion().GetSize();
  SpacingType oSpacing = image->GetSpacing();
  SpacingType spacing;
  for (int i = 0; i < Dimension; i++)
    {
    spacing[i] = oSpacing[i] * oSize[i] / size[i];
    }
  this->SetOutputSpacing(spacing);
  OutputIndexType index;
  InputPointType oPoint;
  InputIndexType oIndex = image->GetLargestPossibleRegion().GetIndex();

  this->UpdateOutputParameters();

  OutputImageType* outputPtr =
      static_cast< OutputImageType * >(this->ProcessObject::GetOutput(0));
  itkAssertOrThrowMacro(outputPtr, "No output Set");

  image->TransformIndexToPhysicalPoint(oIndex, oPoint);
  outputPtr->TransformPhysicalPointToIndex(oPoint, index);
  this->SetOutputStartIndex(index);

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
