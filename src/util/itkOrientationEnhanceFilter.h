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
#ifndef __itkOrientationEnhanceFilter_h
#define __itkOrientationEnhanceFilter_h

#include "itkBoxImageFilter.h"
#include "itkImage.h"

namespace itk
{
template< class TInputImage, class TOutputImage =  TInputImage>
class ITK_EXPORT OrientationEnhanceFilter: public BoxImageFilter< TInputImage,
    TOutputImage >
{
public:
  /** Extract dimension from input and output image. */
  itkStaticConstMacro(InputImageDimension, unsigned int,
      TInputImage::ImageDimension);
    itkStaticConstMacro(OutputImageDimension, unsigned int,
        TOutputImage::ImageDimension);

    /** Convenient typedefs for simplifying declarations. */
    typedef TInputImage InputImageType;
    typedef TOutputImage OutputImageType;

    /** Standard class typedefs. */
    typedef OrientationEnhanceFilter Self;
    typedef ImageToImageFilter< InputImageType, OutputImageType > Superclass;
    typedef SmartPointer< Self > Pointer;
    typedef SmartPointer< const Self > ConstPointer;

    /** Method for creation through the object factory. */
    itkNewMacro(Self);

    /** Run-time type information (and related methods). */
    itkTypeMacro(OrientationEnhanceFilter, BoxImageFilter);

    /** Image typedef support. */
    typedef typename InputImageType::PixelType InputPixelType;
    typedef typename OutputImageType::PixelType OutputPixelType;

    typedef typename InputImageType::RegionType InputImageRegionType;
    typedef typename OutputImageType::RegionType OutputImageRegionType;

    typedef typename InputImageType::SizeType InputSizeType;

#ifdef ITK_USE_CONCEPT_CHECKING
    /** Begin concept checking */
    itkConceptMacro( SameDimensionCheck,
        ( Concept::SameDimension< InputImageDimension, OutputImageDimension > ) );
    itkConceptMacro( InputConvertibleToOutputCheck,
        ( Concept::Convertible< InputPixelType, OutputPixelType > ) );
    itkConceptMacro( InputLessThanComparableCheck,
        ( Concept::LessThanComparable< InputPixelType > ) );
    /** End concept checking */
#endif
  protected:
    OrientationEnhanceFilter();
    virtual ~OrientationEnhanceFilter()
      {}

    void ThreadedGenerateData(const OutputImageRegionType & outputRegionForThread,
        ThreadIdType threadId);

  private:
    OrientationEnhanceFilter(const Self &); //purposely not implemented
    void operator=(const Self &);//purposely not implemented
    };} // end namespace itk

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkOrientationEnhanceFilter.hxx"
#endif

#endif
