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
#ifndef __itkIntensityNormalizerPipeline_h
#define __itkIntensityNormalizerPipeline_h

#include "itkImageToImageFilter.h"
#include "itkUnaryFunctorImageFilter.h"
#include "itkDiscreteGaussianImageFilter.h"
#include "itkMaskedImageToHistogramFilter.h"

#include "util/itkIntensityTableLookupFunctor.h"


namespace itk
{
template< class TInputImage, class TOutputImage=TInputImage >
class ITK_EXPORT IntensityNormalizerPipeline:
  public ImageToImageFilter< TInputImage, TOutputImage >
{
public:
  /** Standard "Self" & Superclass typedef.   */
  typedef IntensityNormalizerPipeline                            Self;
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

  /** Smart pointer typedef support.   */
  typedef SmartPointer< Self >       Pointer;
  typedef SmartPointer< const Self > ConstPointer;

  typedef InputInternalPixelType MaskPixelType;
  typedef Image<MaskPixelType, InputImageDimension> MaskImageType;

  typedef Statistics::MaskedImageToHistogramFilter< InputImageType,
      MaskImageType > HistogramGeneratorType;
  typedef typename HistogramGeneratorType::HistogramType HistogramType;

  typedef DiscreteGaussianImageFilter< InputImageType, InputImageType > GaussianFilterType;

  typedef IntensityTableLookupFunctor< InputImagePixelType, OutputImagePixelType > LookupFunctorType;
  typedef UnaryFunctorImageFilter< InputImageType, OutputImageType,
      LookupFunctorType > LookupTransform;


  /** Run-time type information (and related methods)  */
  itkTypeMacro(IntensityNormalizerPipeline, ImageToImageFilter);

  /** Method for creation through the object factory.  */
  itkNewMacro(Self);

  itkSetMacro(NumberOfLevels, unsigned int);
  itkGetConstMacro(NumberOfLevels, unsigned int);

  /** Method to set/get the mask */
  itkSetInputMacro(MaskImage, MaskImageType);
  itkGetInputMacro(MaskImage, MaskImageType);

  /** Set the pixel value treated as on in the mask.
   * Only pixels with this value will be added to the histogram.
   */
  itkSetGetDecoratedInputMacro(MaskValue, MaskPixelType);

#ifdef ITK_USE_CONCEPT_CHECKING
  /** Begin concept checking */
  itkConceptMacro( SameDimensionCheck,
                   ( Concept::SameDimension< InputImageDimension, OutputImageDimension > ) );
  /** End concept checking */
#endif

protected:
  IntensityNormalizerPipeline();

  virtual ~IntensityNormalizerPipeline()  {}

  void GenerateData();

  void PrintSelf(std::ostream &, Indent) const;
private:
  IntensityNormalizerPipeline(const Self &); //purposely not implemented
  void operator=(const Self &);       //purposely not implemented

  unsigned int m_NumberOfLevels;

};
} // end namespace itk

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkIntensityNormalizerPipeline.hxx"
#endif

#endif
