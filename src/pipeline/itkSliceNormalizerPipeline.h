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
#ifndef __itkSliceNormalizerPipeline_h
#define __itkSliceNormalizerPipeline_h

#include "itkMaskedImageToHistogramFilter.h"
#include "itkImageToImageFilter.h"
#include "itkNumericTraits.h"

namespace itk
{
template< class TInputImage >
class ITK_EXPORT SliceNormalizerPipeline: public ImageToImageFilter<
    TInputImage, TInputImage >
{
public:
  /** Standard "Self" & Superclass typedef.   */
  typedef SliceNormalizerPipeline Self;
  typedef ImageToImageFilter< TInputImage, TInputImage > Superclass;

  /** Extract some information from the image types.  Dimensionality
   * of the two images is assumed to be the same. */
  typedef typename TInputImage::PixelType OutputImagePixelType;
  typedef typename TInputImage::InternalPixelType OutputInternalPixelType;
  typedef typename TInputImage::PixelType InputImagePixelType;
  typedef typename TInputImage::InternalPixelType InputInternalPixelType;

  itkStaticConstMacro(ImageDimension, unsigned int,
      TInputImage::ImageDimension);
    itkStaticConstMacro(SliceDimension, unsigned int,
        TInputImage::ImageDimension-1);

    /** Image typedef support. */
    typedef TInputImage InputImageType;
    typedef TInputImage OutputImageType;
    typedef typename InputImageType::Pointer InputImagePointer;
    typedef typename NumericTraits< InputImagePixelType >::RealType RealType;

    typedef InputInternalPixelType MaskImagePixelType;

    /** Smart pointer typedef support.   */
    typedef SmartPointer< Self > Pointer;
    typedef SmartPointer< const Self > ConstPointer;

    typedef Image< InputImagePixelType, SliceDimension> SliceType;

    typedef Image< MaskImagePixelType, SliceDimension> MaskSliceType;
    typedef Image< MaskImagePixelType, ImageDimension> MaskImageType;

    typedef Statistics::MaskedImageToHistogramFilter<SliceType, MaskSliceType> SliceHistogramType;
    typedef Statistics::MaskedImageToHistogramFilter<InputImageType, MaskImageType> ImageHistogramType;

    /** Run-time type information (and related methods)  */
    itkTypeMacro(SliceNormalizerPipeline, ImageToImageFilter);

    /** Method for creation through the object factory.  */
    itkNewMacro(Self);

    itkSetGetDecoratedInputMacro(DimToFold, int);

    /** Method to set/get the mask */
    itkSetInputMacro(MaskImage, MaskImageType);
    itkGetInputMacro(MaskImage, MaskImageType);

    /** Set the pixel value treated as on in the mask.
     * Only pixels with this value will be added to the histogram.
     */
    itkSetGetDecoratedInputMacro(MaskValue, MaskImagePixelType);

    itkGetConstMacro(MinValue, InputImagePixelType);
    itkGetConstMacro(MeanValue, InputImagePixelType);
    itkGetConstMacro(MaxValue, InputImagePixelType);

    itkSetMacro(NumberOfLevels, unsigned int);
    itkGetConstMacro(NumberOfLevels, unsigned int);

    itkSetMacro(Percentile, double);
    itkGetConstMacro(Percentile, double);
  protected:
    SliceNormalizerPipeline();

    virtual ~SliceNormalizerPipeline()
      {}

    void GenerateData();

    void PrintSelf(std::ostream &, Indent) const;
  private:
    SliceNormalizerPipeline(const Self &); //purposely not implemented
    void operator=(const Self &);//purposely not implemented

    InputImagePixelType m_MinValue;
    InputImagePixelType m_MaxValue;
    InputImagePixelType m_MeanValue;
    double m_Percentile;
    unsigned int m_NumberOfLevels;

    };} // end namespace itk

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkSliceNormalizerPipeline.hxx"
#endif

#endif
