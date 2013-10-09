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
#ifndef __itkMahalanobisDistanceImageFilter_h
#define __itkMahalanobisDistanceImageFilter_h

#include "itkImageToImageFilter.h"
#include "itkVectorImage.h"
#include "itkImageRegionConstIterator.h"
#include "itkTransform.h"

#include "itkWeightedSinglePassMeanCovarianceUpdate.h"
#include "itkStateInterpolatorFunction.h"

#include <vector>

namespace itk
{
template< class TInputImage, class TOutputImage >
class ITK_EXPORT MahalanobisDistanceImageFilter: public ImageToImageFilter<
    TInputImage, TOutputImage >
{
public:

  typedef MahalanobisDistanceImageFilter Self;
  typedef SmartPointer< Self > Pointer;
  typedef SmartPointer< const Self > ConstPointer;
  typedef ImageToImageFilter< TInputImage, TOutputImage > Superclass;itkNewMacro(Self)
  ;itkTypeMacro(MahalanobisDistanceImageFilter, ImageToImageFilter)
  ;

  itkStaticConstMacro(Dimension, unsigned int, TInputImage::ImageDimension);

    typedef TInputImage InputImageType;
    typedef typename InputImageType::Pointer InputImagePointer;
    typedef typename InputImageType::ConstPointer InputImageConstPointer;
    typedef typename InputImageType::RegionType InputImageRegionType;
    typedef typename InputImageType::PixelType InputPixelType;
    typedef typename InputImageType::InternalPixelType InternalPixelType;

    typedef TOutputImage OutputImageType;
    typedef typename OutputImageType::Pointer OutputImagePointer;
    typedef typename OutputImageType::RegionType OutputImageRegionType;
    typedef typename OutputImageType::PixelType OutputPixelType;

    typedef InternalPixelType MaskPixelType;
    typedef Image<MaskPixelType, itkGetStaticConstMacro(Dimension) > MaskImageType;
    typedef VectorImage<InternalPixelType, itkGetStaticConstMacro(Dimension) > StateImageType;

    typedef typename StateImageType::PixelType StateType;
    typedef typename NumericTraits<InputPixelType>::MeasurementVectorType MeasurementVectorType;
    typedef WeightedSinglePassMeanCovarianceUpdate<StateType,MeasurementVectorType> StateFunc;

    typedef typename NumericTraits<InputPixelType>::ScalarRealType ScalarRealType;
    typedef Transform<ScalarRealType, itkGetStaticConstMacro(Dimension), itkGetStaticConstMacro(Dimension) > TransformType;

    typedef StateInterpolatorFunction<StateImageType, double> StateInterpolateType;


    void ConsiderNthChannel(const int N)
      {
      m_ConsiderOrientation |= 1 << N;
      this->Modified();
      }
    void IgnoreNthChannel(const int N)
      {
      m_ConsiderOrientation &= ~(1 << N);
      this->Modified();
      }
    void SetNthChannelLight(const int N)
      {
      m_PositiveOrientation |= 1 << N;
      this->Modified();
      }
    void SetNthChannelDark(const int N)
      {
      m_PositiveOrientation &= ~(1 << N);
      this->Modified();
      }

    /** Method to set/get the mask */
    itkSetInputMacro(MaskImage, MaskImageType);
    itkGetInputMacro(MaskImage, MaskImageType);

    /** Set the pixel value treated as on in the mask.
     * Only pixels with this value will be added to the histogram.
     */
    itkSetGetDecoratedInputMacro(MaskValue, MaskPixelType);
    itkSetConstObjectMacro(StateImage, StateImageType);
    itkGetConstObjectMacro(StateImage, StateImageType);

    itkSetConstObjectMacro(Transform, TransformType);
    itkGetConstObjectMacro(Transform, TransformType);

    itkSetMacro(GlobalState, StateType);
    itkGetConstReferenceMacro(GlobalState, StateType);

    itkSetMacro(OutsideValue, OutputPixelType);
    itkGetConstReferenceMacro(OutsideValue, OutputPixelType);

    TOutputImage* GetDistanceImage();
    TOutputImage* GetOrientImage();

  protected:
    MahalanobisDistanceImageFilter();
    DataObject::Pointer MakeOutput(unsigned int idx);

    void PrintSelf(std::ostream & os, Indent indent) const;

    void BeforeThreadedGenerateData();
    void ThreadedGenerateData(const OutputImageRegionType & outputRegionForThread,
        ThreadIdType threadId);
  private:

    typedef typename InputImageType::PointType InputPointType;
    typedef typename StateImageType::PointType StatePointType;

    typedef ImageRegionConstIterator< InputImageType > InputIteratorType;
    typedef ImageRegionConstIterator< MaskImageType > MaskIteratorType;
    typedef ImageRegionIterator< OutputImageType > OutputIteratorType;

    MahalanobisDistanceImageFilter(const Self &); //purposely not implemented

    void operator=(const Self &);//purposely not implemented

    typename TransformType::ConstPointer m_Transform;
    typename StateImageType::ConstPointer m_StateImage;

    StateType m_GlobalState;
    OutputPixelType m_OutsideValue;
    typename StateInterpolateType::Pointer m_StateInterpolator;

    bool m_HasGlobalState;
    bool m_HasMask;
    bool m_HasStateImage;

    int m_PositiveOrientation;
    int m_ConsiderOrientation;
    };}

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkMahalanobisDistanceImageFilter.hxx"
#endif

#endif
