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
#ifndef __itkRobustMeanVariancePipeline_h
#define __itkRobustMeanVariancePipeline_h

#include "itkImageToImageFilter.h"
#include "itkMaskedImageToHistogramFilter.h"
#include "itkCovarianceSampleFilter.h"
#include "itkSimpleDataObjectDecorator.h"

namespace itk
{
template< class TInputImage >
class ITK_EXPORT RobustMeanVariancePipeline: public ImageToImageFilter<
    TInputImage, TInputImage >
{
public:
  /** Standard "Self" & Superclass typedef.   */
  typedef RobustMeanVariancePipeline Self;
  typedef ImageToImageFilter< TInputImage, TInputImage > Superclass;

  /** Image typedef support. */
  typedef TInputImage InputImageType;
  typedef typename InputImageType::Pointer InputImagePointer;

  /** Smart pointer typedef support.   */
  typedef SmartPointer< Self > Pointer;
  typedef SmartPointer< const Self > ConstPointer;

  /** Run-time type information (and related methods)  */
  itkTypeMacro(RobustMeanVariancePipeline, ImageToImageFilter)
  ;

  /** Method for creation through the object factory.  */
  itkNewMacro(Self)
  ;itkStaticConstMacro(Dimension, unsigned int, TInputImage::ImageDimension);
    typedef typename InputImageType::InternalPixelType InternalPixelType;

    typedef InternalPixelType MaskPixelType;
    typedef Image<MaskPixelType, itkGetStaticConstMacro(Dimension) > MaskImageType;

    typedef Statistics::MaskedImageToHistogramFilter< InputImageType, MaskImageType > ImageToHistogramFilterType;
    typedef typename ImageToHistogramFilterType::HistogramType HistogramType;
    typedef typename ImageToHistogramFilterType::HistogramType::SizeType SizeType;
    typedef typename HistogramType::MeasurementVectorType MeasurementVectorType;

    typedef Statistics::CovarianceSampleFilter< HistogramType > CovarianceAlgorithmType;
    typedef typename CovarianceAlgorithmType::MatrixType CovarianceType;
    typedef typename CovarianceAlgorithmType::MeasurementVectorRealType MeanType;

    typedef SimpleDataObjectDecorator< CovarianceType > CovarianceObjectType;
    typedef SimpleDataObjectDecorator< MeanType > MeanObjectType;

    typedef ProcessObject::DataObjectPointerArraySizeType DataObjectPointerArraySizeType;
    using Superclass::MakeOutput;
    virtual typename DataObject::Pointer MakeOutput(
        DataObjectPointerArraySizeType idx);

    MeanObjectType* GetMeanOutput();
    const MeanObjectType* GetMeanOutput() const;
    MeanType GetMean() const
      {
      return this->GetMeanOutput()->Get();
      }

    CovarianceObjectType* GetCovarianceOutput();
    const CovarianceObjectType* GetCovarianceOutput() const;
    CovarianceType GetCovariance() const
      {
      return this->GetCovarianceOutput()->Get();
      }

    /** Method to set/get the mask */
    itkSetInputMacro(MaskImage, MaskImageType);
    itkGetInputMacro(MaskImage, MaskImageType);

    /** Set the pixel value treated as on in the mask.
     * Only pixels with this value will be added to the histogram.
     */
    itkSetGetDecoratedInputMacro(MaskValue, MaskPixelType);

    ;itkGetConstMacro(NumOfComponents, unsigned int)
    ;itkSetMacro(Percentile, double)
    ;itkGetConstMacro(Percentile, double)
    ;itkSetMacro(NumberOfBins, unsigned int)
    ;itkGetConstMacro(NumberOfBins, unsigned int)
    ;
  protected:
    RobustMeanVariancePipeline();

    virtual ~RobustMeanVariancePipeline()
      {
      }
    void AllocateOutputs();
    void GenerateData();

    void PrintSelf(std::ostream &, Indent) const;
  private:
    RobustMeanVariancePipeline(const Self &); //purposely not implemented
    void operator=(const Self &);//purposely not implemented

    double m_Percentile;
    unsigned int m_NumOfComponents;
    unsigned int m_NumberOfBins;

    typename ImageToHistogramFilterType::Pointer imageToHistogramFilter;
    typename CovarianceAlgorithmType::Pointer covarianceAlgorithm;
    };} // end namespace itk

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkRobustMeanVariancePipeline.hxx"
#endif

#endif
