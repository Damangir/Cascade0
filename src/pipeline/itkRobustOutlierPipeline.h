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
#ifndef __itkRobustOutlierPipeline_h
#define __itkRobustOutlierPipeline_h

#include "itkImageToImageFilter.h"
#include "itkTransform.h"
#include "itkNumericTraits.h"
#include "itkCastImageFilter.h"
#include "itkUnaryFunctorImageFilter.h"

#include "pipeline/itkRobustMeanVariancePipeline.h"
#include "util/itkMahalanobisDistanceImageFilter.h"
#include "util/itkChiSquaredFunctor.h"

namespace itk
{
template< class TInputImage, class TOutputImage = Image<
    typename TInputImage::InternalPixelType, TInputImage::ImageDimension > >
class ITK_EXPORT RobustOutlierPipeline: public ImageToImageFilter< TInputImage,
    TOutputImage >
{
public:
  /** Standard "Self" & Superclass typedef.   */
  typedef RobustOutlierPipeline Self;
  typedef ImageToImageFilter< TInputImage, TOutputImage > Superclass;

  /** Extract some information from the image types.  Dimensionality
   * of the two images is assumed to be the same. */
  typedef typename TOutputImage::PixelType OutputImagePixelType;
  typedef typename TOutputImage::InternalPixelType OutputInternalPixelType;
  typedef typename TInputImage::PixelType InputImagePixelType;
  typedef typename TInputImage::InternalPixelType InputInternalPixelType;

  typedef VectorImage< InputInternalPixelType, TInputImage::ImageDimension > StateImageType;
  typedef Image< InputInternalPixelType, TInputImage::ImageDimension > ScalarImageType;

  /** Image typedef support. */
  typedef TInputImage InputImageType;
  typedef TOutputImage OutputImageType;
  typedef typename InputImageType::Pointer InputImagePointer;
  typedef typename NumericTraits< InputImagePixelType >::RealType RealType;

  /** Smart pointer typedef support.   */
  typedef SmartPointer< Self > Pointer;
  typedef SmartPointer< const Self > ConstPointer;

  typedef RobustMeanVariancePipeline< InputImageType > MeanVariancePipelineType;
  typedef MahalanobisDistanceImageFilter< InputImageType, ScalarImageType > MahalanobisDistanceImageFilterType;
  typedef typename MahalanobisDistanceImageFilterType::StateFunc StateFunc;
  typedef typename MahalanobisDistanceImageFilterType::TransformType TransformType;

  typedef typename MahalanobisDistanceImageFilterType::MaskImageType MaskImageType;
  typedef typename MaskImageType::PixelType MaskPixelType;

  typedef Functor::ChiSquaredFunctor< InputInternalPixelType,
      InputInternalPixelType > ChiSquaredFunctorType;
  typedef UnaryFunctorImageFilter< ScalarImageType, ScalarImageType,
      ChiSquaredFunctorType > ChiFilterType;
  typedef CastImageFilter< ScalarImageType, OutputImageType > CastToOutputType;

  typedef typename MeanVariancePipelineType::MeanType MeanType;
  typedef typename MeanVariancePipelineType::CovarianceType CovarianceType;

  /** Run-time type information (and related methods)  */
  itkTypeMacro(RobustOutlierPipeline, ImageToImageFilter)
  ;

  /** Method for creation through the object factory.  */
  itkNewMacro(Self)
  ;

  /** Method to set/get the mask */
  itkSetInputMacro(MaskImage, MaskImageType);
  itkGetInputMacro(MaskImage, MaskImageType);

  /** Set the pixel value treated as on in the mask.
   * Only pixels with this value will be added to the histogram.
   */
  itkSetGetDecoratedInputMacro(MaskValue, MaskPixelType);

  void ConsiderNthChannel(const int N)
    {
    m_MahalanobisFilter->ConsiderNthChannel(N);
    this->Modified();
    }
  void IgnoreNthChannel(const int N)
    {
    m_MahalanobisFilter->IgnoreNthChannel(N);
    this->Modified();
    }
  void SetNthChannelLight(const int N)
    {
    m_MahalanobisFilter->SetNthChannelLight(N);
    this->Modified();
    }
  void SetNthChannelDark(const int N)
    {
    m_MahalanobisFilter->SetNthChannelDark(N);
    this->Modified();
    }

  virtual void SetStateImage(const StateImageType * _arg)
    {
    if (m_MahalanobisFilter->GetStateImage() != _arg)
      {
      m_MahalanobisFilter->SetStateImage(_arg);
      this->Modified();
      }
    }
  virtual const StateImageType * GetStateImage() const
    {
    return m_MahalanobisFilter->GetStateImage();
    }

  virtual void SetTransform(const TransformType * _arg)
    {
    if (m_MahalanobisFilter->GetTransform() != _arg)
      {
      m_MahalanobisFilter->SetTransform(_arg);
      this->Modified();
      }
    }
  virtual const TransformType * GetTransform() const
    {
    return m_MahalanobisFilter->GetTransform();
    }

  virtual void SetNumberOfBins(const unsigned int _arg)
    {
    if (m_MeanCovCalculator->GetNumberOfBins() != _arg)
      {
      m_MeanCovCalculator->SetNumberOfBins(_arg);
      this->Modified();
      }
    }
  virtual unsigned int GetNumberOfBins() const
    {
    return m_MeanCovCalculator->GetNumberOfBins();
    }

  virtual void SetPercentile(const double _arg)
    {
    if (m_MeanCovCalculator->GetPercentile() != _arg)
      {
      m_MeanCovCalculator->SetPercentile(_arg);
      this->Modified();
      }
    }
  virtual double GetPercentile() const
    {
    return m_MeanCovCalculator->GetPercentile();
    }

  virtual MeanType GetMean() const
    {
    return m_MeanCovCalculator->GetMean();
    }

  virtual CovarianceType GetCovariance() const
    {
    return m_MeanCovCalculator->GetCovariance();
    }

#ifdef ITK_USE_CONCEPT_CHECKING
  /** Begin concept checking */
  itkConceptMacro( SameDimensionCheck,
      ( Concept::SameDimension< TInputImage::ImageDimension, TOutputImage::ImageDimension > ) );
    itkConceptMacro( DoubleCovertibleToOutput,
        ( Concept::Convertible< InputInternalPixelType, OutputInternalPixelType> ) );
    /** End concept checking */
#endif

  protected:
    RobustOutlierPipeline();

    virtual ~RobustOutlierPipeline()
      {
      }

    void GenerateData();

    void PrintSelf(std::ostream &, Indent) const;
  private:
    RobustOutlierPipeline(const Self &); //purposely not implemented
    void operator=(const Self &);//purposely not implemented

    /** Internal filters */
    typename MahalanobisDistanceImageFilterType::Pointer m_MahalanobisFilter;
    typename MeanVariancePipelineType::Pointer m_MeanCovCalculator;
    typename ChiFilterType::Pointer m_ChiFilter;
    typename CastToOutputType::Pointer m_Castor;
    };} // end namespace itk

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkRobustOutlierPipeline.hxx"
#endif

#endif
