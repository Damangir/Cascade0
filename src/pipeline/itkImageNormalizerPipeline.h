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
#ifndef __itkImageNormalizerPipeline_h
#define __itkImageNormalizerPipeline_h

#include "itkImageToImageFilter.h"
#include "itkNumericTraits.h"

namespace itk
{
template< class TInputImage, class TOutputImage=TInputImage >
class ITK_EXPORT ImageNormalizerPipeline:
  public ImageToImageFilter< TInputImage, TOutputImage >
{
public:
  /** Standard "Self" & Superclass typedef.   */
  typedef ImageNormalizerPipeline                            Self;
  typedef ImageToImageFilter< TInputImage, TOutputImage > Superclass;

  /** Extract some information from the image types.  Dimensionality
   * of the two images is assumed to be the same. */
  typedef typename TOutputImage::PixelType         OutputImagePixelType;
  typedef typename TOutputImage::InternalPixelType OutputInternalPixelType;
  typedef typename TInputImage::PixelType          InputImagePixelType;
  typedef typename TInputImage::InternalPixelType  InputInternalPixelType;
  itkStaticConstMacro(InputImageDimension, unsigned int,
                      TInputImage::ImageDimension);
  itkStaticConstMacro(OutputImageDimension, unsigned int,
                      TOutputImage::ImageDimension);

  /** Image typedef support. */
  typedef TInputImage                      InputImageType;
  typedef TOutputImage                     OutputImageType;
  typedef typename InputImageType::Pointer InputImagePointer;
  typedef typename NumericTraits< InputImagePixelType >::RealType RealType;

  /** Smart pointer typedef support.   */
  typedef SmartPointer< Self >       Pointer;
  typedef SmartPointer< const Self > ConstPointer;

  /** Run-time type information (and related methods)  */
  itkTypeMacro(ImageNormalizerPipeline, ImageToImageFilter);

  /** Method for creation through the object factory.  */
  itkNewMacro(Self);

  itkSetMacro(TargetPeak, RealType);
  itkGetConstMacro(TargetPeak, RealType);

  itkSetMacro(TargetMax, RealType);
  itkGetConstMacro(TargetMax, RealType);

  itkSetMacro(TargetMin, RealType);
  itkGetConstMacro(TargetMin, RealType);

  itkGetConstMacro(MaxValue, RealType);
  itkGetConstMacro(MinValue, RealType);
  itkGetConstMacro(Peak, RealType);

  itkSetMacro(NumberOfBins, unsigned int);
  itkGetConstMacro(NumberOfBins, unsigned int);

  itkSetMacro(Percentile, double);
  itkGetConstMacro(Percentile, double);

#ifdef ITK_USE_CONCEPT_CHECKING
  /** Begin concept checking */
  itkConceptMacro( SameDimensionCheck,
                   ( Concept::SameDimension< InputImageDimension, OutputImageDimension > ) );
  /** End concept checking */
#endif

protected:
  ImageNormalizerPipeline();

  virtual ~ImageNormalizerPipeline()  {}

  void GenerateData();

  void PrintSelf(std::ostream &, Indent) const;
private:
  ImageNormalizerPipeline(const Self &); //purposely not implemented
  void operator=(const Self &);       //purposely not implemented

  RealType m_TargetPeak;
  RealType m_TargetMin;
  RealType m_TargetMax;

  double m_Percentile;
  unsigned int m_NumberOfBins;

  RealType m_MaxValue;
  RealType m_MinValue;
  RealType m_Peak;

};
} // end namespace itk

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkImageNormalizerPipeline.hxx"
#endif

#endif
